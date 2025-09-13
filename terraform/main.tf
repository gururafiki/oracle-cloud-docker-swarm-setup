terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "5.0.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  private_key_path = var.private_key_path
  fingerprint      = var.fingerprint
  region           = var.region
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

resource "oci_core_vcn" "vcn" {
  compartment_id = var.compartment_ocid
  cidr_block     = "10.0.0.0/16"
  display_name   = "vcn"
  dns_label      = var.name_prefix
}

resource "oci_core_internet_gateway" "ig" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "internet-gateway"
}

resource "oci_core_route_table" "rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.ig.id
  }
}

resource "oci_core_security_list" "rules" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "rules"

  # Allow all internal VCN traffic
  ingress_security_rules {
    protocol = "all"
    source   = "10.0.0.0/16"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }
  
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }
  
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 2376
      max = 2376
    }
  }
  
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 2377
      max = 2377
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 27017
      max = 27017
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 8000
      max = 8000
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 9000
      max = 9000
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 9001
      max = 9001
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 9080
      max = 9080
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 9443
      max = 9443
    }
  }
  
  # Container network discovery (TCP & UDP)
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 7946
      max = 7946
    }
  }
  
  ingress_security_rules {
    protocol = "17"
    source   = "0.0.0.0/0"
    udp_options {
      min = 7946
      max = 7946
    }
  }
  
  # Overlay network traffic
  ingress_security_rules {
    protocol = "17"
    source   = "0.0.0.0/0"
    udp_options {
      min = 4789
      max = 4789
    }
  }
}

# Get default security list for the VCN
data "oci_core_security_lists" "default" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  filter {
    name   = "display_name"
    values = ["Default Security List for ${oci_core_vcn.vcn.display_name}"]
  }
}

resource "oci_core_subnet" "subnet" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  cidr_block     = "10.0.1.0/24"
  display_name   = "subnet"
  dns_label      = var.name_prefix
  route_table_id = oci_core_route_table.rt.id
  
  # Combine default security list with custom rules
  security_list_ids = [
    data.oci_core_security_lists.default.security_lists[0].id,
    oci_core_security_list.rules.id
  ]
}

data "oci_core_images" "os" {
  compartment_id   = var.compartment_ocid
  operating_system = var.operating_system
  shape            = var.shape
}


resource "oci_core_instance" "node" {
  count               = var.node_count
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain].name
  shape               = var.shape
  display_name        = "${var.name_prefix}-amd-node-${count.index}"
  timeouts {
    create = "60m"
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.subnet.id
    assign_public_ip = true
    hostname_label   = "${var.name_prefix}-${count.index}"
  }

  source_details {
    source_id   = data.oci_core_images.os.images[0].id
    source_type = "image"
  }

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_in_gbs
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
  }
}
