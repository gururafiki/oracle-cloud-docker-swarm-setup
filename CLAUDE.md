# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Infrastructure-as-code to stand up an **Oracle Cloud (OCI) Always-Free Docker Swarm cluster** and deploy services to it. Two cooperating layers:

- `terraform/` — provisions OCI compute instances + networking.
- `ansible/` — hardens the instances, forms the Swarm, and deploys a stack.
- `docker-stack/` — `docker stack deploy` templates for Swarm (uses Docker secrets / Swarm-mode features).
- `docker-compose/` — standalone `docker compose up` templates intended to be deployed *inside* Dokploy, not to the Swarm directly.

## The pipeline (how the layers connect)

1. **Terraform** creates N instances and outputs their public + private IPs (`terraform/outputs.tf`).
2. **`ansible/generate_inventory.sh <workspace>`** reads those Terraform outputs (via `terraform output -json`) and writes `<workspace>.inventory.ini`. **Node index 0 becomes the `[manager]`, all others become `[workers]`.** This script is the only bridge between the two layers.
3. **An Ansible playbook** consumes that inventory to configure nodes and deploy a stack.

Inventory files (`ansible/*inventory.ini`), `terraform/*.tfvars`, `*secrets.yaml`, and `*.env` are all gitignored — they hold environment-specific config/secrets.

## Common commands

All Ansible commands assume the working dir is `ansible/`; all Terraform commands assume `terraform/`.

```bash
# --- Terraform (in terraform/) ---
terraform init
terraform plan -out swarm.plan
terraform apply swarm.plan
terraform destroy -auto-approve

# Workspaces = environments. Per-env vars live in <workspace>.tfvars:
terraform workspace new prod
terraform apply -var-file="prod.tfvars"
terraform workspace select prod

# --- Inventory bridge (in ansible/) ---
./generate_inventory.sh default          # arg = terraform workspace name

# --- Ansible (in ansible/) ---
export ANSIBLE_HOST_KEY_CHECKING=false   # needed for never-before-seen hosts
ansible-playbook -i default.inventory.ini portainer_stack.yml -u ubuntu --private-key ~/.ssh/oci_key
```

There is no test suite. "Testing" here means tearing down and rebuilding a cluster to verify reproducibility; the full one-liners are in `README.md` (Testing Reproducibility section). `--private-key` must be the pair of the `ssh_public_key_path` set in `terraform.tfvars`.

## Ansible architecture (the important part)

**Every playbook shares the same 3-play skeleton**, then optionally appends deploy plays:

```yaml
- hosts: all      → role: oci-swarm-node   (+ per-playbook ufw_*_ports / ssh_* vars)
- hosts: manager  → role: swarm_manager    (+ service roles like dokploy)
- hosts: workers  → role: swarm_worker
```

`oci-swarm-node` is a **meta-role** (`roles/oci-swarm-node/tasks/main.yml`) that composes the leaf roles in a deliberate order: `ssh` → `fail2ban` → `ufw` → `iptables` → `docker`, then fires deferred handlers to finalize the firewall. Reusable building blocks live in `roles/*/tasks/main.yml` and `roles/*/handlers/main.yml`.

### The OCI iptables gotcha (do not break this ordering)

OCI's Ubuntu images ship a restrictive iptables config: a `FORWARD ... REJECT --reject-with icmp-host-prohibited` rule plus an INPUT chain that only allows port 22. Two things must hold for Swarm to work and for any service port to be reachable:

- **Both layers must open a port.** UFW rules (`ufw_tcp_ports`/`ufw_udp_ports` per playbook) AND the OCI Security List (`public_tcp_ports`/`public_udp_ports` in Terraform) must allow it. Forgetting the Terraform side is the usual reason a port is unreachable.
- The `iptables` role **removes** the `FORWARD REJECT` rule at the start and inserts Swarm ports (2377, 7946, 4789); the matching handler **re-appends** `FORWARD REJECT` only at the very end (after Docker installs and mangles iptables). The "Finalize firewall setup" task in `oci-swarm-node` triggers these handlers in order. If you reorder roles or move the handlers, Swarm node-to-node traffic or Docker's own forwarding will break.

Swarm formation: `swarm_manager` runs `docker swarm init --advertise-addr {{ private_ip }}`; `swarm_worker` joins using `hostvars[groups['manager'][0]].manager_token` and the manager's `private_ip`. The `private_ip` for each host comes from the inventory line written by `generate_inventory.sh`. Only single-manager setups are supported (see TODO in `roles/swarm_manager`).

## Playbooks and their distinguishing trait

- `portainer_stack.yml` — cleanest starting point: bare Swarm + Portainer. Deploys via plain `copy` of the compose file.
- `mongo_stack.yml` — demonstrates the **Docker secrets** pattern (`echo -n ... | docker secret create`) plus staging init files onto the host.
- `dokploy_stack.yml` — demonstrates **templated secrets**: secrets are injected into `docker-compose.yaml` via Ansible `template` (look for `{{ postgres_password }}`) for images that don't support Docker secrets.
- `dokploy.yml` / `dokploy_remote_swarm.yml` — install Dokploy (via its `install.sh`) or prepare a bare Swarm to register as a Dokploy *remote server*.

**Dokploy playbooks set `ssh_permit_root_login: "yes"`** (Dokploy needs root SSH to remote servers) and hardcode `ssh_authorized_key` to `~/.ssh/oci_key.pub`. The `ssh` role only installs the root key when `permit_root_login == "yes"`. Non-Dokploy playbooks use `"no"`.

## Before deploying secret-bearing stacks

The `mongo`/`dokploy` stacks need a real secrets file (the `.example` is a template, and `*secrets.yaml` is gitignored):

- Copy `docker-stack/templates/<svc>/secrets.example.yaml` → `secrets.yaml` and fill it in.
- For mongo, also set a strong password in `docker-stack/templates/mongo/mongodb-init/mongo-init.js`.

## Hard assumptions

- **Ubuntu only.** Roles use `apt`, the Docker apt repo, and the `ubuntu` user. Changing Terraform's `operating_system` away from `"Canonical Ubuntu"` will break the Ansible roles.
- Default user is `ubuntu`; files are staged to `/home/ubuntu/`.
- Free-tier shapes: default is 2× `VM.Standard.E2.1.Micro` (AMD); the README documents switching to 4× ARM `VM.Standard.A1.Flex`.
