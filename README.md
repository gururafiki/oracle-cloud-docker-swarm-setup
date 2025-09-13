# Oracle Cloud Always Free Docker Swarm Setup
Oracle Cloud Infrastructure setup using Terraform and Ansible to deploy performant Docker swarm (cluster of Docker daemons) using Always free resources.

This repository contains a battle-tested solution using **Terraform + Ansible** to setup docker swarm cluster programmatically with 3 services:
- [Portainer](https://www.portainer.io/) - container management
- [MiniO](https://www.min.io/) - self-hosted blob-storage (S3 alternative)
- [MongoDB](https://www.mongodb.com/) - no-SQL database

## Package Overview
---

### 🛠 Terraform Infrastructure as Code
**File Structure**:
```bash
oracle-swarm/
├── main.tf                   # OCI resources
├── variables.tf              # Variables definitions
├── outputs.tf                # IP addresses for Ansible
└── terraform.example.tfvars  # Example template for secrets and configuration variables
```

#### *main.tf* - Core Infrastructure:
Contains defintion to setup:
* VCN (Virtual Cloud Network)
* Internet Gateway
* Route table
* Subnet
* Security rules to allow traffic over the ports:
  * used by services in *docker-compose/docker-compose.yaml*
  * used by Docker Swarm
  * HTTP/HTTPS ports for future load-balancer setup (TODO)
* Instances

#### *variables.tf* - Variables definitions:
Contains defintion of varialbes, you can set default values there or define more varaibles prior to adding them to *terraform.tfvars*

#### *outputs.tf* - For Ansible Inventory:
Outputs instances Public/Private IPs that are later converted to Ansible invetory. 

#### *terraform.example.tfvars* - Template for secrets and configuration variables:
Template file for variables required for terraform deployment.

---

### ⚙️ Ansible Configuration
**File Structure**:
```bash
ansible/
├── docker_swarm.yml       # Ansible Playbook
└── generate_inventory.sh  # Bash script for inventory generation
```

#### *docker_swarm.yml* - Playbook
Ansible playbook for Unbuntu instances that:
1. Installs necessary dependencies (Docker, UFW).
2. *Important* Cleans iptables included in default Oracle images. Without this step you will be only able to connect to instances via SSH.
3. Setups firewall rules using UFW. (TODO)
4. Initializes 1 manager for a Docker Swarm.
5. Joins all other instances as workers to Docker Swarm.
6. Copies files needed for services to run (Mongo init script, Nginx configuration, etc)
7. Creates secrets for the services.
8. Deploys services from docker compose yaml configuration.


#### *generate_inventory.sh* - Inventory generation script
We will use this script to read terraform outputs and convert them to *inventory.ini* file that can be used by Anisble Playbook.

> *Note*: Terraform has a plugin for Ansible: https://registry.terraform.io/providers/ansible/ansible/latest and Ansible has a plugin for terraform. Process of generating inventory for Ansible can be further automated. Contributions are welcome :D

---

## Runbook

### 1. Follow the [Step-by-step guide to create instances in Oracle Cloud using Terraform](terraform/README.md) to deploy your infrustructure

> *Important*: if you update `operating_system` variable to different than Ubuntu - ansible playbook from this example won't work for you. You can make chaanges to it to support other operating systems (contributions are welcome).

### 2. (Optional) Connect via SSH to created instances 

> *Important*: `<ssh_private_key_path>` should point to private key that is that pair for `ssh_public_key_path` from terraform configuration.

#### 1. Verify Key Permissions
```bash
chmod 400 <ssh_private_key_path>
```
e.g.
```bash
chmod 400 ~/.ssh/oci_key
```

#### 2. Connect to Instances

Now we can conncet to all of the instances we have created.
To do this we can take Public IPs that were outputed by `terraform apply` command.
For Ubuntu operating system default user will be `ubuntu`.
```bash
ssh -i <ssh_private_key_path> <user>@<public_ip>
```
e.g.
```bash
ssh -i ~/.ssh/oci_key ubuntu@123.45.67.89
```

#### 3. Update SSH Config File (Recommended)
Create `~/.ssh/config` with:
```config
Host swarm-node-i
  HostName <public_ip>
  User <user>
  IdentityFile <ssh_private_key_path>
```
e.g.
```config
Host swarm-node-1
  HostName 123.45.67.89
  User ubuntu
  IdentityFile ~/.ssh/oci_key
```

Then connect with:
```bash
ssh swarm-node-1
```

### 3. Generate Ansible Inventory
```bash
cd ansible
chmod +x generate_inventory.sh
./generate_inventory.sh
cd ..
```

### 4. Prepare secrets
1. Rename *secrets.example.yaml* to *docker-compose/secrets.yaml* and fill with desired values.
2. Update *docker-compose/mongodb-init/mongo-init.js* to strong password for user we are going to create. (TODO: this should be moved to secrets as well, contributions are welcome)

### 4. Run Ansible Playbook

> *Imporant*: if you haven't connected to instances before over SSH - you may need to approve that you want to connect to unknown host.
> *Important*: `<ssh_private_key_path>` should point to private key that is that pair for `ssh_public_key_path` from terraform configuration.
> *Important*: this playbook is written for AMD64 chips, it needs to be slightly changed for ARM chips if you are using them.

```bash
cd ansible
ansible-playbook -i inventory.ini docker_swarm.yml -u <user> --private-key <ssh_private_key_path>
cd ..
```
e.g.
```bash
cd ansible
ansible-playbook -i inventory.ini docker_swarm.yml -u ubuntu --private-key ~/.ssh/oci_key
cd ..
```

### 5. (Optional) 🧪 Testing Reproducibility
1. **Destroy cluster**:
```bash
terraform destroy
```

2. **Rebuild identical cluster**:
```bash
cd terraform && terraform apply -auto-approve && cd ../ansible && ./generate_inventory.sh && ansible-playbook -i inventory.ini docker_swarm.yml -u <user> --private-key <ssh_private_key_path> && cd ..
```
e.g.
```bash
cd terraform && terraform apply -auto-approve && cd ../ansible && ./generate_inventory.sh && ansible-playbook -i inventory.ini docker_swarm.yml -u ubuntu --private-key ~/.ssh/oci_key && cd ..
```

### 6. Test your endpoints

That's it. Now you can access your services using IP of any node from the swarm. 

> *Important note*: This setup Docker Swarm won't forward user's IP to your services, to solve this you can experiment with setting up your own load balancer and reverse proxy like traefik or nginx (contributions are welcome)

Below you can see the list of endpoints you can access:
1. http://<public_ip>:9080 - HTTP access to Portainer
2. https://<public_ip>:9443 - HTTPS access to Portainer
3. http://<public_ip>:9001 - HTTP Access to MiniO
4. mongodb://root:mongo_root_password@<public_ip>:27017/ - MongoDB connection string


---

This setup gives you **one-click reproducible clusters** with version-controlled infrastructure and configuration. Perfect for testing upgrades, disaster recovery drills, and environment consistency.