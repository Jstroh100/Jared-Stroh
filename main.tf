terraform {
  required_version = ">= 1.5.0"

  # --- Remote State Backend (Google Cloud Storage) ---
  backend "gcs" {
    bucket = "jared-tf-state-379020"
    prefix = "prod/multi-cloud"
  }

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
  }
}

# --- Providers ---
provider "aws" {
  region = "us-east-1"
}

provider "azurerm" {
  features {}
}

provider "google" {
  project = "hidden-matter-379020"
  region  = "us-east1"
}

# ==============================================================================
# 1. STORAGE ARCHITECTURE (Multi-Cloud Fleet)
# ==============================================================================

# --- AWS S3 Bucket ---
resource "aws_s3_bucket" "iac_backup" {
  bucket = "jared-iac-archive-2026"

  tags = {
    Environment = "Dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "iac_backup_versioning" {
  bucket = aws_s3_bucket.iac_backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

# --- Azure Blob Storage ---
resource "azurerm_resource_group" "iac_rg" {
  name     = "jared-iac-rg"
  location = "eastus"
}

resource "azurerm_storage_account" "iac_store" {
  name                     = "jarediacstore2026"
  resource_group_name      = azurerm_resource_group.iac_rg.name
  location                 = azurerm_resource_group.iac_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "iac_container" {
  name                  = "documents"
  storage_account_name  = azurerm_storage_account.iac_store.name
  container_access_type = "private"
}

# --- GCP Cloud Storage ---
resource "google_storage_bucket" "iac_bucket" {
  name          = "jared-iac-archive-379020"
  location      = "US-EAST1"
  force_destroy = false

  versioning {
    enabled = true
  }
}

# ==============================================================================
# 2. AWS NETWORKING (10.0.0.0/16)
# ==============================================================================

resource "aws_vpc" "enterprise_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "ms-aws-vpc"
    Environment = "Dev"
    Tier        = "Core-Network"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.enterprise_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "ms-aws-public-1a"
    Tier = "Public"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.enterprise_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "ms-aws-private-1a"
    Tier = "Private"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.enterprise_vpc.id

  tags = {
    Name = "ms-aws-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.enterprise_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "ms-aws-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# ==============================================================================
# 3. AZURE NETWORKING (10.1.0.0/16)
# ==============================================================================

resource "azurerm_virtual_network" "enterprise_vnet" {
  name                = "ms-azure-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.iac_rg.location
  resource_group_name = azurerm_resource_group.iac_rg.name

  tags = {
    Environment = "Dev"
    Tier        = "Core-Network"
  }
}

resource "azurerm_subnet" "azure_public_subnet" {
  name                 = "ms-azure-public-subnet"
  resource_group_name  = azurerm_resource_group.iac_rg.name
  virtual_network_name = azurerm_virtual_network.enterprise_vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "azure_private_subnet" {
  name                 = "ms-azure-private-subnet"
  resource_group_name  = azurerm_resource_group.iac_rg.name
  virtual_network_name = azurerm_virtual_network.enterprise_vnet.name
  address_prefixes     = ["10.1.2.0/24"]
}

# ==============================================================================
# 4. GCP NETWORKING (10.2.0.0/16)
# ==============================================================================

# Custom VPC (auto_create_subnetworks = false is standard enterprise practice)
resource "google_compute_network" "enterprise_vpc" {
  name                    = "ms-gcp-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "gcp_public_subnet" {
  name          = "ms-gcp-public-subnet"
  ip_cidr_range = "10.2.1.0/24"
  region        = "us-east1"
  network       = google_compute_network.enterprise_vpc.id
}

resource "google_compute_subnetwork" "gcp_private_subnet" {
  name          = "ms-gcp-private-subnet"
  ip_cidr_range = "10.2.2.0/24"
  region        = "us-east1"
  network       = google_compute_network.enterprise_vpc.id

  # Enables private Google APIs access without public internet IP
  private_ip_google_access = true
}

# ==============================================================================
# 5. UNIFIED MULTI-CLOUD OUTPUTS
# ==============================================================================

output "aws_vpc_id" {
  description = "AWS VPC ID"
  value       = aws_vpc.enterprise_vpc.id
}

output "azure_vnet_id" {
  description = "Azure VNet ID"
  value       = azurerm_virtual_network.enterprise_vnet.id
}

output "gcp_network_id" {
  description = "GCP VPC Network ID"
  value       = google_compute_network.enterprise_vpc.id
}