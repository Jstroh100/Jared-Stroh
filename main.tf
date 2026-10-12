terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "gcs" {
    bucket = "jared-tf-state-379020"
    prefix = "terraform/state"
  }
}

# ==========================================
# PROVIDER CONFIGURATIONS
# ==========================================

provider "aws" {
  region = "us-east-1"
}

provider "azurerm" {
  features {}
}

provider "google" {
  project = "jared-tf-state-379020"
  region  = "us-east1"
}

# ==========================================
# 1. AWS ISOLATED NETWORK TOPOLOGY (10.0.0.0/16)
# ==========================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "enterprise-aws-vpc"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "aws-public-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "aws-public-subnet"
    Tier = "Public"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "aws-private-subnet"
    Tier = "Private-Isolated"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "aws-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "aws-private-rt"
  }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_security_group" "private_sg" {
  name        = "aws-private-isolated-sg"
  description = "Block all public ingress; allow internal VPC traffic only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow internal VPC traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aws-private-sg"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "test_vm" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true

  tags = {
    Name        = "aws-routing-test-vm"
    Environment = "Dev"
  }
}

# ==========================================
# 2. AZURE ISOLATED NETWORK & COMPUTE (10.1.0.0/16)
# ==========================================

resource "azurerm_resource_group" "rg" {
  name     = "enterprise-network-rg"
  location = "eastus"

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "enterprise-azure-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.1.0.0/16"]

  tags = {
    Environment = "Production"
  }
}

resource "azurerm_subnet" "public" {
  name                 = "azure-public-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "private" {
  name                 = "azure-private-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.2.0/24"]
}

resource "azurerm_network_security_group" "private_nsg" {
  name                = "azure-private-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowInternalVNetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "10.1.0.0/16"
  }

  security_rule {
    name                       = "DenyInternetInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Production"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.private_nsg.id
}

resource "tls_private_key" "azure_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_public_ip" "azure_vm_pip" {
  name                = "azure-vm-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "azure_vm_nic" {
  name                = "azure-vm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.azure_vm_pip.id
  }
}

resource "azurerm_linux_virtual_machine" "azure_test_vm" {
  name                            = "azure-test-vm"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = "Standard_B1s"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.azure_vm_nic.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.azure_ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    Environment = "Dev"
  }
}

# ==========================================
# 3. GCP ISOLATED NETWORK & COMPUTE (10.2.0.0/16)
# ==========================================

resource "google_compute_network" "custom_vpc" {
  name                    = "enterprise-gcp-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public" {
  name          = "gcp-public-subnet"
  ip_cidr_range = "10.2.1.0/24"
  region        = "us-east1"
  network       = google_compute_network.custom_vpc.id
}

resource "google_compute_subnetwork" "private" {
  name                     = "gcp-private-subnet"
  ip_cidr_range            = "10.2.2.0/24"
  region                   = "us-east1"
  network                  = google_compute_network.custom_vpc.id
  private_ip_google_access = true
}

resource "google_compute_firewall" "allow_internal_only" {
  name    = "gcp-allow-internal-only"
  network = google_compute_network.custom_vpc.name

  allow {
    protocol = "all"
  }

  source_ranges = ["10.2.0.0/16"]
  description   = "Permit ingress strictly from internal GCP VPC CIDR"
}

resource "google_compute_instance" "gcp_test_vm" {
  name         = "gcp-routing-test-vm"
  machine_type = "e2-micro"
  zone         = "us-east1-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public.id

    access_config {
      // Ephemeral external IP
    }
  }

  labels = {
    environment = "dev"
  }
}