# Cloudflare resources for the Muffin deployment (provider v5).
#
# Gated on var.cloudflare_domain — leave it "" and nothing here is created (OCI-only deploy).
# When set, this creates: proxied DNS A records for <chat>/<api>.<domain> → the VM, a Zero-Trust
# Access application per hostname, an allow-by-email policy, and a service token for API clients.
#
# NOTE: Cloudflare's SSL/TLS mode must be "Full (strict)" for the proxied origin (Traefik serves a
# real Let's Encrypt cert via DNS-01). Set it once in the dashboard (SSL/TLS → Overview) — it is
# intentionally NOT managed here to avoid clobbering other apps on the zone.

locals {
  cf_enabled = var.cloudflare_domain != ""
  cf_hostnames = local.cf_enabled ? {
    chat = "${var.cloudflare_chat_subdomain}.${var.cloudflare_domain}"
    api  = "${var.cloudflare_api_subdomain}.${var.cloudflare_domain}"
  } : {}
  # Service token needs the "Access: Service Tokens: Edit" permission on the API token. Off by
  # default so a DNS+Access-only token works; enable for programmatic API access.
  cf_service_token = local.cf_enabled && var.cloudflare_create_service_token
}

# Proxied A records → the Swarm manager VM (node 0).
resource "cloudflare_dns_record" "muffin" {
  for_each = local.cf_hostnames
  zone_id  = var.cloudflare_zone_id
  name     = each.value
  type     = "A"
  content  = oci_core_instance.node[0].public_ip
  ttl      = 1 # 1 = automatic (required when proxied)
  proxied  = true
  comment  = "muffin ${each.key} (managed by terraform)"
}

# Zero-Trust Access: identity policy (browser/SSO) for the listed emails.
resource "cloudflare_zero_trust_access_policy" "muffin" {
  count      = local.cf_enabled ? 1 : 0
  account_id = var.cloudflare_account_id
  name       = "muffin-allow-emails"
  decision   = "allow"
  include    = [for e in var.cloudflare_access_emails : { email = { email = e } }]
}

# Service-token policy (programmatic API): must be `non_identity` ("Service Auth") so the
# token bypasses the interactive login when sent as CF-Access-Client-Id/Secret headers.
resource "cloudflare_zero_trust_access_policy" "muffin_service" {
  count      = local.cf_service_token ? 1 : 0
  account_id = var.cloudflare_account_id
  name       = "muffin-service-token"
  decision   = "non_identity"
  include = [{
    service_token = { token_id = cloudflare_zero_trust_access_service_token.muffin_api[0].id }
  }]
}

resource "cloudflare_zero_trust_access_application" "muffin" {
  for_each         = local.cf_hostnames
  zone_id          = var.cloudflare_zone_id
  name             = "muffin-${each.key}"
  domain           = each.value
  type             = "self_hosted"
  session_duration = "24h"
  policies = concat(
    [{ id = cloudflare_zero_trust_access_policy.muffin[0].id, precedence = 1 }],
    local.cf_service_token ? [{
      id         = cloudflare_zero_trust_access_policy.muffin_service[0].id
      precedence = 2
    }] : [],
  )
}

# Service token for programmatic API access (send as CF-Access-Client-Id / CF-Access-Client-Secret).
# Optional — requires "Access: Service Tokens: Edit" on the API token (set cloudflare_create_service_token=true).
resource "cloudflare_zero_trust_access_service_token" "muffin_api" {
  count      = local.cf_service_token ? 1 : 0
  account_id = var.cloudflare_account_id
  name       = "muffin-api-service-token"
}

output "cloudflare_hostnames" {
  value = values(local.cf_hostnames)
}

output "cloudflare_access_service_token_client_id" {
  value     = local.cf_service_token ? cloudflare_zero_trust_access_service_token.muffin_api[0].client_id : null
  sensitive = true
}

output "cloudflare_access_service_token_client_secret" {
  value     = local.cf_service_token ? cloudflare_zero_trust_access_service_token.muffin_api[0].client_secret : null
  sensitive = true
}
