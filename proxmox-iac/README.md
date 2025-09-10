# 🚀 DevSecOps Project: Hybrid Cluster Infrastructure with Proxmox, K3s and Synology NAS

## 📚 Table of Contents
- [Quick Overview](#quick-overview)
- [Project Description](#project-description)
- [Project Goals](#project-goals)
- [System Architecture](#system-architecture)
  - [Physical Layer (Proxmox Hosts)](#physical-layer-proxmox-hosts)
  - [Network Architecture and VLANs](#network-architecture-and-vlans)
- [Core Components and Services](#core-components-and-services)
- [Automation (Infrastructure as Code - IaC)](#automation-infrastructure-as-code---iac)
  - [Terraform](#terraform)
  - [Ansible](#ansible)
  - [Repository Structure](#repository-structure)
- [DevSecOps Compliance](#devsecops-compliance)
- [Action Plan](#action-plan)
- [Requirements](#requirements)
- [Usage](#usage)
- [License](#license)

## 🔍 Quick Overview
Hybrid DevSecOps infrastructure (HA): Proxmox VE + K3s. IaC with Terraform/Ansible for repeatability and security. VLAN segmentation (88/100), Synology NFS, monitoring with Prometheus/Grafana/Loki. Secure access via Cloudflare Tunnel and SSL certificates.

## 📘 Project Description
This project delivers a complete hybrid IT infrastructure based on DevSecOps principles. Its goal is to create a highly available, scalable, and secure environment for containerized application deployment. It combines:
- Virtualization (Proxmox VE)
- Lightweight container orchestration (K3s)
- Centralized NFS storage (Synology NAS)
- Advanced networking and security via MikroTik

Everything is version-controlled and automated using Terraform and Ansible.

## 🎯 Project Goals
- **High Availability (HA):** Proxmox cluster with K3s (embedded etcd).
- **Network Segmentation:** VLANs 88 (cluster) and 100 (admin) for isolation.
- **Infrastructure as Code (IaC):** All configuration stored and repeatable via Terraform and Ansible.
- **Centralized Storage:** Synology NAS as shared NFS for Proxmox backups and K3s volumes.
- **Monitoring:** Prometheus, Grafana and Loki stack for full observability.
- **Secure Access:** Expose services via Cloudflare Tunnel and manage SSL with cert-manager.
- **DevSecOps Compliance:** Security from day one, continuous monitoring and versioning.

## 🖥️ System Architecture

### Physical Layer (Proxmox Hosts)
| Hostname         | Hardware   | LAN IP (VLAN 100) | Cluster IP (VLAN 88) | Role                     |
|------------------|------------|-------------------|-----------------------|--------------------------|
| proxmox-dell     | Dell i5 8th| 192.168.100.2     | 192.168.88.2          | Proxmox Host, NAT Master |
| proxmox-lenovo   | Lenovo i3  | 192.168.100.3     | 192.168.88.3          | Proxmox Host, HA Backup  |
| proxmox-dell-2   | Dell i5 10th|192.168.100.4     | 192.168.88.4          | Proxmox Host, HA Backup  |
| synology-nas     | Synology   | N/A               | 192.168.88.5          | NFS Storage              |

### Network Architecture and VLANs
- **VLAN 100 – Management:** Access to Proxmox GUI, SSH, admin traffic. Gateway: MikroTik (192.168.100.1)
- **VLAN 88 – Cluster Traffic (Isolated):** Proxmox HA, K3s, NFS. Gateway (VIP via Keepalived): 192.168.88.1

## ⚙️ Core Components and Services
| Component         | Role |
|------------------|------|
| Proxmox VE       | Virtualization with HA and automatic failover |
| K3s              | Lightweight Kubernetes (3 master nodes) |
| Synology NAS     | NFS shared storage for K3s and Proxmox backups |
| MikroTik Router  | VLAN routing, firewall, DHCP, VPN |
| Monitoring Stack | Prometheus, Grafana, Loki for metrics/logs |
| MetalLB          | LoadBalancer IP assignment for K3s services |
| Cloudflare Tunnel| Expose services securely without open ports |

## 🤖 Automation (Infrastructure as Code - IaC)

### Terraform
Used for VM provisioning in Proxmox VE:
- Create VMs from template
- Assign them to HA groups
- Mount NFS storage

### Ansible
Used for configuring OS and installing services:
- Debian base config (SSH, users, updates)
- Install K3s and core services (Traefik, MetalLB, cert-manager)
- Monitoring stack, node_exporter, Proxmox config backup
- Application deployment (Flask, Ingress, PVC)

### Repository Structure
```
├── .github/         # GitHub Actions (CI/CD)
├── ansible/         # Roles and playbooks
│   └── roles/
├── failover_oracle/ # Failover files
├── inventory/       # Ansible inventory files
├── terraform/       # Terraform configs
│   ├── modules/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
└── README.md        # Project description
```

## ✅ DevSecOps Compliance
- **Shift Left Security:** Firewalls, SSH hardening, secrets
- **IaC:** Git versioning and automation
- **Idempotency:** Playbooks and Terraform produce same result repeatedly
- **Modularity:** Roles and reusable modules
- **Monitoring:** Live metrics and logs for infrastructure + apps

## 🗺️ Action Plan
Project executed in phases: manual setup → automation (IaC) → CI/CD → monitoring → documentation.

## 🧰 Requirements
- 3x physical Proxmox servers (Dell/Lenovo)
- MikroTik Router with VLAN 100 and 88
- Synology NAS with NFS shares
- Admin machine with Git, Terraform, Ansible
- Cloudflare account (DNS + Tunnel)

## 🚀 Usage
Deployment and usage instructions available in `docs/` and inline comments of Terraform / Ansible code.

## 📝 License
This project is licensed under [Your License Name, e.g. MIT License].