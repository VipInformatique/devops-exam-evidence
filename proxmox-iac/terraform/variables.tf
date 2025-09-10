###############################################################################
# VARIABLES GLOBAL
###############################################################################

variable "pm_api_url" {
  description = "URL do Proxmox API (https://pve-host:8006)"
  type        = string
}

variable "pm_api_token" {
  description = "Połączony token API w formacie <user>@pve!token=<secret>"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Klucz publiczny SSH dla cloud-init."
  type        = string
}

variable "k3s_masters" {
  description = "Definicje maszyn MASTER K3s."
  type = map(object({
    name          = string
    vm_id         = number
    target_node   = string
    ip_address    = string
    mac_address   = string
    cpu_cores     = number
    memory_mib    = number
    disk_size_gib = number
    vlan_id       = number
    vlan_bridge   = string
    gateway       = string
    ci_user       = string
    datastore_id  = string

  }))

  default = {
    k8s-master-01 = {
      name          = "k8s-master-01"
      vm_id         = 101
      target_node   = "proxmox-dell"
      ip_address    = "192.168.88.6/28"
      mac_address   = "BC:24:11:D4:6B:C3"
      cpu_cores     = 2
      memory_mib    = 6144
      disk_size_gib = 32
      vlan_id       = 88
      vlan_bridge   = "vmbr1"
      gateway       = "192.168.88.1"
      ci_user       = "devistor"
      datastore_id  = "local-lvm"
    },
    k8s-master-02 = {
      name          = "k8s-master-02"
      vm_id         = 102
      target_node   = "proxmox-dell10"
      ip_address    = "192.168.88.7/28"
      mac_address   = "BC:24:11:2A:1B:C3"
      cpu_cores     = 2
      memory_mib    = 4096
      disk_size_gib = 32
      vlan_id       = 88
      vlan_bridge   = "vmbr1"
      gateway       = "192.168.88.1"
      ci_user       = "devistor"
      datastore_id  = "local-lvm"
    },
    k8s-master-03 = {
      name          = "k8s-master-03"
      vm_id         = 103
      target_node   = "proxmox-lenovo"
      ip_address    = "192.168.88.8/28"
      mac_address   = "BC:24:11:65:7E:88"
      cpu_cores     = 2
      memory_mib    = 4096
      disk_size_gib = 32
      vlan_id       = 88
      vlan_bridge   = "vmbr1"
      gateway       = "192.168.88.1"
      ci_user       = "devistor"
      datastore_id  = "local-lvm"
    }
  }
}

variable "k3s_workers" {
  description = "Definicje maszyn WORKER K3s."
  type = map(object({
    name          = string
    vm_id         = number
    target_node   = string
    ip_address    = string
    mac_address   = string
    cpu_cores     = number
    memory_mib    = number
    disk_size_gib = number
    vlan_id       = number
    vlan_bridge   = string
    gateway       = string
    ci_user       = string
    datastore_id  = string

  }))

  default = {
    k8s-worker-01 = {
      name          = "k8s-worker-01"
      vm_id         = 104
      target_node   = "proxmox-dell"
      ip_address    = "192.168.88.9/28"
      mac_address   = "BC:24:11:50:21:B8"
      cpu_cores     = 2
      memory_mib    = 4096
      disk_size_gib = 32
      vlan_id       = 88
      vlan_bridge   = "vmbr1"
      gateway       = "192.168.88.1"
      ci_user       = "devistor"
      datastore_id  = "synology-nfs"
    },
    k8s-worker-02 = {
      name          = "k8s-worker-02"
      vm_id         = 105
      target_node   = "proxmox-dell10"
      ip_address    = "192.168.88.10/28"
      mac_address   = "BC:24:11:92:3B:06"
      cpu_cores     = 2
      memory_mib    = 4096
      disk_size_gib = 32
      vlan_id       = 88
      vlan_bridge   = "vmbr1"
      gateway       = "192.168.88.1"
      ci_user       = "devistor"
      datastore_id  = "synology-nfs"
    },
    k8s-worker-03 = {
      name          = "k8s-worker-03"
      vm_id         = 106
      target_node   = "proxmox-lenovo"
      ip_address    = "192.168.88.11/28"
      mac_address   = "BC:24:11:AA:84:59"
      cpu_cores     = 2
      memory_mib    = 4096
      disk_size_gib = 32
      vlan_id       = 88
      vlan_bridge   = "vmbr1"
      gateway       = "192.168.88.1"
      ci_user       = "devistor"
      datastore_id  = "synology-nfs"
    }
  }
}