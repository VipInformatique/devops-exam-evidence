data "oci_core_subnet" "failover_subnet" {
  subnet_id = var.subnet_ocid
}

data "oci_core_vcn" "failover_vcn" {
  vcn_id = data.oci_core_subnet.failover_subnet.vcn_id
}

variable "admin_cidr" {
  description = "Publiczny adres/CIDR dopuszczony do SSH (np. 94.239.249.70/32)"
  type        = string
  default     = "94.239.249.70/32"
}

resource "oci_core_default_security_list" "vcn_default_sl" {
  manage_default_resource_id = data.oci_core_vcn.failover_vcn.default_security_list_id
  display_name = "Default Security List for vcn-failover"
  compartment_id             = var.compartment_ocid

  # ---------- INGRESS ----------
  # SSH 22 z Twojego IP
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.admin_cidr
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 22
      max = 22
    }
    description = "SSH 22 from admin IP"
  }

  # ICMP type 3, code 4 (Fragmentation needed) z Internetu
  ingress_security_rules {
    protocol    = "1" # ICMP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    icmp_options {
      type = 3
      code = 4
    }
    description = "ICMP type 3, code 4 from Internet"
  }

  # ICMP type 3 z VCN 10.0.0.0/16
  ingress_security_rules {
    protocol    = "1" # ICMP
    source      = "10.0.0.0/16"
    source_type = "CIDR_BLOCK"
    icmp_options {
      type = 3
    }
    description = "ICMP type 3 from VCN 10.0.0.0/16"
  }

  # ---------- EGRESS ----------
  # NTP (UDP 123)
  egress_security_rules {
    protocol         = "17" # UDP
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    udp_options {
      min = 123
      max = 123
    }
    description = "NTP (UDP 123)"
  }

  # DNS TCP 53
  egress_security_rules {
    protocol         = "6" # TCP
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    tcp_options {
      min = 53
      max = 53
    }
    description = "DNS (TCP 53)"
  }

  # DNS UDP 53
  egress_security_rules {
    protocol         = "17" # UDP
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    udp_options {
      min = 53
      max = 53
    }
    description = "DNS (UDP 53)"
  }

  # Cloudflare Tunnel (TCP 7844)
  egress_security_rules {
    protocol         = "6" # TCP
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    tcp_options {
      min = 7844
      max = 7844
    }
    description = "Cloudflare Tunnel (TCP 7844)"
  }

  # HTTPS 443 – fallback + update'y
  egress_security_rules {
    protocol         = "6" # TCP
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    tcp_options {
      min = 443
      max = 443
    }
    description = "HTTPS (TCP 443)"
  }

  # HTTP 80 – fallback + update'y
  egress_security_rules {
    protocol         = "6" # TCP
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    tcp_options {
      min = 80
      max = 80
    }
    description = "HTTP (TCP 80)"
  }

  # PostgreSQL Neon (TCP 5432)
  egress_security_rules {
    protocol         = "6" # TCP
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    tcp_options {
      min = 5432
      max = 5432
    }
    description = "PostgreSQL (TCP 5432)"
  }

  # SMTP/SSL (TCP 465)
  egress_security_rules {
    protocol         = "6" # TCP
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    tcp_options {
      min = 465
      max = 465
    }
    description = "SMTP/SSL (TCP 465)"
  }
}
