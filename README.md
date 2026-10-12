# Multi-Cloud Enterprise Infrastructure as Code (IaC)

Declarative, multi-cloud enterprise architecture provisioned across **Amazon Web Services (AWS)**, **Microsoft Azure**, and **Google Cloud Platform (GCP)** using **Terraform** and version-controlled via Git.

Remote state locking is unified within a centralized Google Cloud Storage (GCS) backend (`gs://jared-tf-state-379020/terraform/state`).

---

## 🏛️ Architecture Matrix (8 Core Capabilities)

| Capability | AWS (`us-east-1`) | Azure (`eastus`) | GCP (`us-east1`) |
| :--- | :--- | :--- | :--- |
| **1. Virtual Networks** | Custom VPC (`10.0.0.0/16`), IGW, public/private subnets, custom RTs | Enterprise VNet (`10.1.0.0/16`), subnets, delegated DB subnets | Custom VPC (`10.2.0.0/16`), custom subnets, non-auto CIDRs |
| **2. Network Security** | Strict Security Groups (internal CIDR ingress only) | Network Security Group (NSG) with Internet drop rules | Private VPC Firewall Rules (internal-only CIDR scopes) |
| **3. Compute Instances** | Amazon Linux 2023 (`t3.micro`) | Ubuntu 22.04 LTS (`Standard_B1s`) with dynamic RSA SSH | Debian 11 (`e2-micro`) with ephemeral public access |
| **4. Serverless Runtime** | AWS Lambda (Python 3.11) + IAM AssumeRole execution | Azure Function App (Python 3.11, Consumption Plan `Y1`) | Cloud Functions Gen 2 (Python 3.11, GCS artifact trigger) |
| **5. Managed Kubernetes** | AWS EKS 1.28 + Multi-AZ private worker node group | Azure AKS with private `Standard_B2s` system node pool | Google Cloud GKE private cluster with `e2-micro` pool |
| **6. Relational SQL** | AWS RDS PostgreSQL 15 (`db.t4g.micro`, air-gapped) | Azure PostgreSQL Flexible Server (`B_Standard_B1ms`) | GCP Cloud SQL PostgreSQL 15 (`db-f1-micro`, private IP) |
| **7. IAM & Cryptography** | Least-privilege IAM execution roles & EKS CNI policies | SystemAssigned Managed Identities & 4096-bit RSA keys | Dynamic 16-character cryptographic password generation |
| **8. Central Observability** | CloudWatch Log Group (`/enterprise/central-audit-logs`) | Azure Log Analytics Workspace (`PerGB2018`, 30-day retention) | Cloud Logging Central Sink (exporting `WARNING+` to GCS) |

---

## 🌐 Network Topology & Non-Overlapping CIDRs

All virtual network topologies are intentionally designed with isolated, non-overlapping address blocks to avoid IP collision during future hybrid interconnection or cross-cloud transit peering:

```text
       ┌────────────────────────── Multi-Cloud IaC ──────────────────────────┐
       │                                                                      │
       ▼                                  ▼                                   ▼
  [ AWS VPC ]                       [ Azure VNet ]                      [ GCP VPC ]
  10.0.0.0/16                        10.1.0.0/16                        10.2.0.0/16
  ├── Public:  10.0.1.0/24           ├── Public:  10.1.1.0/24           ├── Public:  10.2.1.0/24
  ├── Private: 10.0.2.0/24           ├── Private: 10.1.2.0/24           └── Private: 10.2.2.0/24
  └── Priv-B:  10.0.3.0/24           └── DB-Sub:  10.1.3.0/24