# Failover VM — Oracle Cloud (OCI) Terraform quickstart

## Prereqs
- OCI account + API key configured in `~/.oci/config` (profile `DEFAULT` or your own).
- IAM policy allowing you to manage instances in the target compartment.
- Existing VCN/subnet (provide its `subnet_ocid`).
- Terraform >= 1.6

## Deploy
```bash
cd failover/terraform
terraform init
terraform plan -var-file=failover.tfvars.example
terraform apply -var-file=failover.tfvars.example