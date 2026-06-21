# Muffin Agent — Oracle Cloud Swarm stack

Deploys the full 13-service [muffin-agent](../../../../muffin-agent) LangGraph stack to a
**single ARM Always-Free** OCI VM running a single-node Docker Swarm, behind **Traefik** with
**Cloudflare** DNS/Access in front.

Only two services are ever exposed to the internet — the **chat UI** and the **LangGraph API**.
Every MCP / infra service (OpenBB, Firecrawl ×6, SearxNG, OpenSandbox, Postgres, Redis) stays
private on the Swarm overlay (`exposedByDefault=false`, no published ports).

```
Cloudflare (proxied DNS + Access)
   └─ Traefik v3 (only :80/:443) ── muffin.rafiki.guru      → agent-chat-ui
                                  └─ muffin-api.rafiki.guru  → langgraph-api
   muffin-net overlay (private): postgres · redis · openbb-mcp · searxng · firecrawl-* · opensandbox
```

## Files

| File | Purpose |
|------|---------|
| `docker-compose.yaml` | Swarm stack (Ansible-templated). |
| `traefik.yml` | Traefik v3 static config (Ansible-templated; Cloudflare DNS-01 wildcard TLS). |
| `config.example.yml` | Copy to `config.yml` (gitignored) — **non-secret** deploy config (domain, registry, models). |
| `secrets.example.yaml` | Copy to `secrets.yaml` (gitignored) — **secrets** (API keys, passwords, tokens). |
| `build-and-push.sh` | Build the 3 ARM64 images and push to GHCR (local alternative to CI). |

Two non-secret runtime files you copy in from the muffin-agent repo (gitignored): `config.toml`,
`searxng/`. (App/provider keys are **not** copied as `.env` files anymore — they come from
`secrets.yaml`.)

## Prerequisites

- An OCI tenancy with the Always-Free ARM quota, an API signing key, and an SSH keypair.
- A domain in **Cloudflare** (here `rafiki.guru`) and **one Cloudflare API token** scoped to
  **Zone:DNS:Edit + Zone:Read + Account → Access: Apps/Policies/Service Tokens: Edit**. The same
  token drives Terraform *and* Traefik's DNS-01 challenge. Grab the **Zone ID** + **Account ID**
  from the zone Overview page (right sidebar → API).
- Images on GHCR (via the GitHub Actions workflow, below) — make the `muffin` package **public** so
  the VM pulls without a PAT.
- Terraform + Ansible locally.

## Deploy

Paths below are relative to the repo root (`oracle-cloud-docker-swarm-setup/`).

### 1. Build & push the images

**CI (recommended):** [muffin-agent/.github/workflows/build-images.yml](../../../../muffin-agent/.github/workflows/build-images.yml)
builds the 3 ARM64 images on a native arm64 runner and pushes `ghcr.io/gururafiki/muffin:{api,openbb,ui}`
on every push to `main`. Set the repo **variable** `PUBLIC_API_URL=https://muffin-api.rafiki.guru`
(Settings → Secrets and variables → Actions → Variables), run it once (`workflow_dispatch`), then
make the `muffin` GHCR package **public**.

**Local alternative:** `REGISTRY=ghcr.io/gururafiki/muffin DOMAIN=rafiki.guru ./build-and-push.sh`
(needs `docker login ghcr.io`; bakes `NEXT_PUBLIC_API_URL=https://api.$DOMAIN`, so pass
`API_URL=https://muffin-api.rafiki.guru` explicitly to match the subdomains).

### 2. Stage config + secrets (in `docker-stack/templates/muffin/`)

```bash
cp config.example.yml  config.yml          # edit: domain, subdomains, registry, models (NON-secret)
cp secrets.example.yaml secrets.yaml        # edit: API keys, passwords, cf_dns_api_token (SECRETS)
M=../../../../muffin-agent
cp   $M/extras/opensandbox/config.toml  config.toml
cp -r $M/extras/searxng                  searxng
```

### 3. Provision VM + Cloudflare (Terraform)

`terraform.tfvars` already targets a single `VM.Standard.A1.Flex` (4 OCPU / 24 GB) and includes the
Cloudflare block. Fill the OCI creds + the Cloudflare token/zone/account IDs, then:

```bash
cd terraform
terraform init
terraform apply        # creates the VM AND the muffin/muffin-api DNS records + Access app/policy/service-token
terraform output -json cloudflare_access_service_token_client_id      # for programmatic API calls
terraform output -json cloudflare_access_service_token_client_secret
```

One-time in the Cloudflare dashboard: set **SSL/TLS → Overview → Full (strict)** (Traefik serves a
real Let's Encrypt cert via DNS-01, so strict validates).

### 4. Configure the Swarm + deploy (Ansible)

```bash
cd ../ansible
./generate_inventory.sh default
export ANSIBLE_HOST_KEY_CHECKING=false
ansible-playbook -i default.inventory.ini muffin_stack.yml -u ubuntu --private-key ~/.ssh/oci_key
```

The playbook hardens the node, forms the Swarm, loads `config.yml` + `secrets.yaml`, stages the
config files, creates the Docker secrets, and `docker stack deploy`s. (Registry login is skipped
when `registry_password` is empty — public GHCR pulls anonymously.)

### 5. Auth

The LangGraph API has no auth by default. Terraform already created a **Cloudflare Access**
application over both hostnames with an allow-by-email policy + a service token (step 3). Optionally
add **LangGraph custom auth** (origin defense-in-depth + per-user memory): set `MUFFIN_API_TOKEN`
and/or `CF_ACCESS_TEAM_DOMAIN` + `CF_ACCESS_AUD` as env on `langgraph-api` (add to `config.yml`/
`secrets.yaml` + the compose `environment:`). See
[muffin-agent/auth.py](../../../../muffin-agent/auth.py). Once the Access JWT is verified, the email
becomes `configurable.user_id` → real per-user memory; then set `memory_debug_user_id: ""`.

## Verify

```bash
# On the node:
ssh -i ~/.ssh/oci_key ubuntu@<ip> docker service ls          # all 1/1
ssh -i ~/.ssh/oci_key ubuntu@<ip> docker stack ps muffin      # converged (api may restart until deps healthy)

# From anywhere (add CF-Access-Client-Id/Secret headers if Access is on):
curl https://muffin-api.rafiki.guru/ok                        # {"ok": true}
open  https://muffin.rafiki.guru                              # chat UI

# Confirm MCP/infra is NOT exposed (all should refuse/time out):
for p in 8001 3000 3002 8080 8888 5432 6379; do nc -vz -w3 <ip> $p; done
```

## Notes & caveats

- **ARM64**: the VM is aarch64. Before first deploy, confirm every third-party image has an arm64
  manifest: `docker buildx imagetools inspect <image>`. The OpenSandbox runtime images
  (`opensandbox/execd`, `opensandbox/egress`, referenced in `config.toml`) are the most likely to
  lack arm64 — if the sandbox fails, the core agent still works; the `execute_python` tool degrades.
- **Secrets are plaintext in the Swarm service spec** (`docker service inspect`) — the LangGraph
  image reads plain env vars, so they can't use Docker secret files without a custom entrypoint
  (roadmap). The Postgres/CF Docker secrets ARE encrypted in raft.
- **Swarm has no startup ordering** — `depends_on` conditions are dropped; `langgraph-api` /
  `firecrawl-*` restart until dependencies are healthy, then converge.
- **Memory**: ~13.5 GB of limits budgeted on the 24 GB VM; Firecrawl workers lowered to 2.
- **Backups**: single node = no HA. Back up the `langgraph-data` volume (`pg_dump`) periodically.
- **Editing `traefik.yml` / `config.toml`** then re-running the playbook re-stages the bind-mounted
  files; restart the service (`docker service update --force muffin_traefik`).
- **Cloudflare config drift:** Terraform owns the `muffin`/`muffin-api` records + Access app; the
  zone's other records (in `rafiki.guru.txt`) are untouched.
