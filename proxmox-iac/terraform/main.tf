###############################################################################
# VARIABLES
###############################################################################
variable "with_clone" {
  type    = bool
  default = true
}

# Mapowanie „node → ID szablonu”
locals {
  template_by_node = {
    proxmox-dell    = 108
    proxmox-dell10  = 113
    proxmox-lenovo  = 114
  }
}

###############################################################################
# MASTERS
###############################################################################
resource "proxmox_virtual_environment_vm" "k3s_master" {
  for_each   = var.k3s_masters

  name        = each.value.name
  node_name   = each.value.target_node
  vm_id       = each.value.vm_id
  description = "K3s master node ${each.value.name}"


  dynamic "clone" {
    for_each = var.with_clone ? [1] : []
    content {
      vm_id        = local.template_by_node[each.value.target_node]  # ID szablonu
      full         = true                                            # pełny klon
      datastore_id = each.value.datastore_id                         # gdzie zapisać dysk
    }
  }

  
  cpu {
    cores = each.value.cpu_cores
    type  = "kvm64"
  }

  memory {
    dedicated = each.value.memory_mib
  }

  scsi_hardware = "virtio-scsi-single"

 
  network_device {
    bridge       = each.value.vlan_bridge
    model        = "virtio"
    mac_address  = each.value.mac_address
    firewall     = false
    disconnected = false
  }

 
  initialization {
    ip_config {
      ipv4 {
        address = each.value.ip_address
        gateway = each.value.gateway
      }
    }

    dns {
      servers = ["1.1.1.1"]
    }

    user_account {
      username = each.value.ci_user
      keys     = [var.ssh_public_key]
    }
  }

  agent {
    enabled = true
  }
}

###############################################################################
# WORKERS
###############################################################################
resource "proxmox_virtual_environment_vm" "k3s_worker" {
  for_each = var.k3s_workers

  name        = each.value.name
  node_name   = each.value.target_node
  vm_id       = each.value.vm_id
  description = "K3s worker node ${each.value.name}"

 
  dynamic "clone" {
    for_each = var.with_clone ? [1] : []
    content {
      vm_id        = local.template_by_node[each.value.target_node]
      full         = true
      datastore_id = each.value.datastore_id   # ← dla workerów to „synology-nfs”
    }
  }


  cpu {
    cores = each.value.cpu_cores
    type  = "kvm64"
  }

  memory {
    dedicated = each.value.memory_mib
  }

  scsi_hardware = "virtio-scsi-single"


  network_device {
    bridge       = each.value.vlan_bridge
    model        = "virtio"
    mac_address  = each.value.mac_address
    firewall     = false
    disconnected = false
  }


  initialization {
    ip_config {
      ipv4 {
        address = each.value.ip_address
        gateway = each.value.gateway
      }
    }

    dns {
      servers = ["1.1.1.1"]
    }

    user_account {
      username = each.value.ci_user
      keys     = [var.ssh_public_key]
    }
  }

  agent {
    enabled = true
  }
}

###############################################################################
# HA
###############################################################################
resource "proxmox_virtual_environment_hagroup" "k3s_cluster" {
  group        = "k3s-cluster"
  comment      = "Grupa HA dla workerów K3s"

  nodes = {
    proxmox-dell    = 1
    proxmox-dell10  = 1
    proxmox-lenovo  = 1
  }

  restricted  = true
  no_failback = true
}

resource "proxmox_virtual_environment_haresource" "workers" {
  for_each = proxmox_virtual_environment_vm.k3s_worker

  resource_id  = "vm:${each.value.vm_id}"
  group        = proxmox_virtual_environment_hagroup.k3s_cluster.group
  state        = "started"
  max_restart  = 3
  max_relocate = 1

  depends_on = [proxmox_virtual_environment_hagroup.k3s_cluster]
}