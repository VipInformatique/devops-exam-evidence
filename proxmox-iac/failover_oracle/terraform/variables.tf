variable "compartment_ocid" {
  description = "Target compartment OCID"
  type        = string
}

variable "availability_domain" {
  description = "Availability Domain name, e.g. 'YbcB:EU-PARIS-1-AD-1'"
  type        = string
}

variable "subnet_ocid" {
  description = "Subnet OCID for the primary VNIC"
  type        = string
}

variable "vm_name" {
  description = "Instance display name"
  type        = string
}

variable "shape" {
  description = "OCI shape (e.g. VM.Standard.E4.Flex or VM.Standard.E2.1.Micro)"
  type        = string
}

variable "ocpus" {
  description = "vCPU count (Flex shapes only)"
  type        = number
  default     = 2
}

variable "memory_in_gbs" {
  description = "RAM in GB (Flex shapes only)"
  type        = number
  default     = 4
}

variable "image_ocid" {
  description = "Image OCID (Ubuntu or Oracle Linux)"
  type        = string
}

variable "assign_public_ip" {
  description = "Assign a public IP on the primary VNIC"
  type        = bool
  default     = true
}

variable "nsg_id" {
  description = "Network Security Group OCID (optional)"
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key for the VM user"
  type        = string
}

variable "ssh_user" {
  description = "SSH username (ubuntu/opc)"
  type        = string
  default     = "ubuntu"
}

variable "region" {
  description = "OCI region, e.g. eu-paris-1"
  type        = string
}

variable "oci_profile" {
  description = "Profile name in ~/.oci/config"
  type        = string
  default     = "DEFAULT"
}

variable "ssh_private_key_path" {
  description = "Local path to the SSH private key (used in generated Ansible inventory)"
  type        = string
}

variable "inventory_path" {
  description = "Path to write the generated Ansible inventory (optional)"
  type        = string
  default     = ""
}

variable "host_alias" {
  description = "Host alias used in the generated Ansible inventory"
  type        = string
  default     = "failover-DeviStor"
}

variable "oci_private_key_password" {
  description = "Passphrase for OCI API private key (if any)"
  type        = string
  default     = ""
}
