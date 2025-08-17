# Manage an existing OCI instance and generate Ansible inventory

resource "oci_core_instance" "failover" {
  # These attributes must match the current VM settings in OCI
  availability_domain = var.availability_domain         # e.g. YbcB:EU-PARIS-1-AD-1
  compartment_id      = var.compartment_ocid
  display_name        = var.vm_name                     # "failover-DeviStor"
  shape               = var.shape                       # "VM.Standard.E2.1.Micro"

  # Shape config applies only to Flex shapes; for E2.1.Micro this block is skipped
  dynamic "shape_config" {
    for_each = endswith(var.shape, ".Flex") ? [1] : []
    content {
      ocpus         = var.ocpus
      memory_in_gbs = var.memory_in_gbs
    }
  }

  # Keep source details minimal to avoid unnecessary drift after import
  source_details {
    source_type = "image"
    source_id   = var.image_ocid
    # Intentionally not setting boot_volume_size_in_gbs to avoid plan noise
  }

  # Primary VNIC; set only what's required
  create_vnic_details {
    subnet_id        = var.subnet_ocid
    assign_public_ip = var.assign_public_ip
    # hostname_label is optional and omitted here to minimize drift
    nsg_ids          = var.nsg_id == "" ? null : [var.nsg_id]
  }

  # Provide SSH public key; omit cloud-init to keep plans clean after import
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }

  # Prevent cosmetic changes after import from showing up in every plan
  lifecycle {
    ignore_changes = [
      metadata,
      source_details,
      create_vnic_details,
      shape_config,
      agent_config,
      extended_metadata,
      preserve_boot_volume,
    ]
  }
}

# Read attached primary VNIC and resolve IP addresses
data "oci_core_vnic_attachments" "primary" {
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.failover.id
}

data "oci_core_vnic" "primary" {
  vnic_id = data.oci_core_vnic_attachments.primary.vnic_attachments[0].vnic_id
}

# Compose Ansible inventory path and host
locals {
  ansible_host   = var.assign_public_ip ? data.oci_core_vnic.primary.public_ip_address : data.oci_core_vnic.primary.private_ip_address
  inventory_path = var.inventory_path == "" ? "${path.module}/../ansible/inventory_sanitized.ini" : var.inventory_path
}

# Generate a simple inventory for Ansible
resource "local_file" "ansible_inventory" {
  filename = local.inventory_path
  content  = <<EOT
[failover]
${var.host_alias} ansible_host=${local.ansible_host} ansible_user=${var.ssh_user} ansible_ssh_private_key_file=${var.ssh_private_key_path}
EOT

  depends_on = [data.oci_core_vnic.primary]
}

# Useful outputs
output "instance_id" { value = oci_core_instance.failover.id }
output "public_ip"   { value = data.oci_core_vnic.primary.public_ip_address }
output "private_ip"  { value = data.oci_core_vnic.primary.private_ip_address }
output "ssh_user"    { value = var.ssh_user }
