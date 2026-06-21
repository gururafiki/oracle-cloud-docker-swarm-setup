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

# === Cloudflare (optional — see cloudflare.tf). Empty cloudflare_domain disables all CF resources. ===
variable "cloudflare_domain" {
  description = "Apex domain managed in Cloudflare (e.g. rafiki.guru). Empty string disables Cloudflare."
  type        = string
  default     = ""
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token (Zone:DNS:Edit + Zone:Read + Account Access: Apps/Policies/Service Tokens: Edit)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for cloudflare_domain (zone overview page → API section)."
  type        = string
  default     = ""
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (zone overview page → API section)."
  type        = string
  default     = ""
}

variable "cloudflare_chat_subdomain" {
  description = "Subdomain for the chat UI."
  type        = string
  default     = "chat"
}

variable "cloudflare_api_subdomain" {
  description = "Subdomain for the LangGraph API."
  type        = string
  default     = "api"
}

variable "cloudflare_access_emails" {
  description = "Emails allowed through Cloudflare Access (Zero Trust)."
  type        = list(string)
  default     = []
}

variable "cloudflare_create_service_token" {
  description = "Create a Cloudflare Access service token (needs 'Access: Service Tokens: Edit' on the API token)."
  type        = bool
  default     = false
}
