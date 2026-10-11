\# Enterprise Multi-Cloud Infrastructure as Code (IaC)



Automated provisioning of core storage and isolated network perimeters across Amazon Web Services (AWS), Microsoft Azure, and Google Cloud Platform (GCP) using HashiCorp Terraform.



\## Architecture Highlights



\* \*\*Remote State Management:\*\* Configured with Google Cloud Storage (`gcs`) backend with object versioning enabled to ensure state consistency and locking across execution environments.

\* \*\*Non-Overlapping Network Topology:\*\*

&#x20; \* \*\*AWS VPC:\*\* `10.0.0.0/16` with dual-tier subnets (Public ingress `10.0.1.0/24` with Internet Gateway and air-gapped Private `10.0.2.0/24`).

&#x20; \* \*\*Azure Virtual Network (VNet):\*\* `10.1.0.0/16` (`eastus`) with segregated subnets (`10.1.1.0/24` and `10.1.2.0/24`).

&#x20; \* \*\*GCP Custom VPC:\*\* `10.2.0.0/16` (`us-east1`) custom subnet mode with Private Google Access enabled.

\* \*\*Multi-Cloud Storage Fleet:\*\* S3 bucket with versioning and environment tagging, Azure Blob Storage account with container controls, and GCP Cloud Storage buckets.



\## Project Structure



```text

├── .gitignore               # Excludes provider binaries, local cache, and state files

├── main.tf                  # Multi-cloud provider definitions, state backend, and resources

├── .terraform.lock.hcl      # Provider dependency lock file

└── README.md                # Project documentation

