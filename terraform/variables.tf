variable "tenancy_ocid" {
  description = "OCID of your Tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID of the User"
  type        = string
}

variable "private_key_path" {
  description = "Path to the private key"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the public key"
  type        = string
}

variable "region" {
  description = "OCI Region"
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the Compartment"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key"
  type        = string
}

variable "name_prefix" {
  description = "Name prefix"
  type        = string
}

variable "operating_system" {
  description = "Operating system"
  type        = string
}

variable "availability_domain" {
  description = "Availability domain"
  type        = number
}

variable "shape" {
  description = "Shape"
  type        = string
}

variable "node_count" {
  description = "Node count"
  type        = number
}

variable "ocpus" {
  description = "CPUs"
  type        = number
}

variable "memory_in_gbs" {
  description = "RAM"
  type        = number
}

variable "public_tcp_ports" {
  description = "Public TCP ports"
  type        = set(number)
}

variable "public_udp_ports" {
  description = "Public UDP ports"
  type        = set(number)
}
