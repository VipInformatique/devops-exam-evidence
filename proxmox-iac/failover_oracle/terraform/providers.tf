terraform {
  required_version = ">= 1.5.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 7.14"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# Provider reads credentials from ~/.oci/config (profile DEFAULT)
provider "oci" {
  region              = var.region
  config_file_profile = var.oci_profile
  # If your API key has a passphrase, uncomment the next line and set TF_VAR_oci_private_key_password
  # private_key_password = var.oci_private_key_password
}
