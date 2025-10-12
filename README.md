# Oracle Cloud Always Free Docker Swarm Setup
Oracle Cloud Infrastructure setup using Terraform and Ansible to deploy performant Docker swarm (cluster of Docker daemons) using Always free resources.

This repository contains a battle-tested solution using **Terraform + Ansible** to setup Docker Swarm cluster and deploy various services to it.

## Package Overview
---

### File Structure:
```bash
oracle-cloud-docker-swarm-setup/
├── terraform/                # Terraform Infrastructure as Code for Oracle Cloud to setup compute instances and network
├── ansible/                  # Ansible Playbooks for Docker Swarm cluster creation and services deployment
├── docker-stack/             # Docker Stack templates that can be run deployed to Docker Swarm Cluster
└── docker-compose/           # Example template for secrets and configuration variables
```

---

## Runbook

### 1. Provision infrastructure in Oracle Cloud using Terraform

Follow the [Step-by-step guide to create instances in Oracle Cloud using Terraform](terraform/README.md) to deploy your infrustructure

> *Important*: if you update `operating_system` variable to different than Ubuntu - ansible playbook from this example won't work for you. You can make changes to it to support other operating systems (contributions are welcome).

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

### 3.Configure your instances, create Docker Swarm and deploy containers using Ansible

Follow the [Step-by-step guide to setup Docker Swarm cluster using Ansible](ansible/README.md)

> *Important*: if you have updated `operating_system` variable from *terraform.tfvars* to different than Ubuntu - ansible playbook from this example won't work for you. You can make changes to it to support other operating systems (contributions are welcome).

### 4. (Optional) 🧪 Testing Reproducibility
#### 1. Destroy cluster:
```bash
cd terraform && terraform destroy -auto-approve && cd ..
```

#### 2. Rebuild identical cluster:
We will add a little 30 sleep between provisioning infra and running ansible playbook to make sure instances started:
```bash
cd terraform && terraform apply -auto-approve && sleep 60s && cd ../ansible && ./generate_inventory.sh default && ansible-playbook -i default.inventory.ini <playbook>.yml -u <user> --private-key <ssh_private_key_path> && cd ..
```
e.g.
```bash
cd terraform && terraform apply -auto-approve && sleep 60s && cd ../ansible && ./generate_inventory.sh default && export ANSIBLE_HOST_KEY_CHECKING=false && ansible-playbook -i default.inventory.ini portainer_stack.yml -u ubuntu --private-key ~/.ssh/oci_key && cd ..
```
or combined to perform all together:
```bash
cd terraform && terraform destroy -auto-approve  && sleep 10s && terraform init -upgrade && terraform plan -out swarm.plan &&  terraform apply swarm.plan && sleep 60s && cd ../ansible && ./generate_inventory.sh default && export ANSIBLE_HOST_KEY_CHECKING=false && ansible-playbook -i default.inventory.ini portainer_stack.yml -u ubuntu --private-key ~/.ssh/oci_key && cd ..
```
or the same combined, but for dokploy (make sure you have `[dokploy]` host defined in *inventory.ini*)
```bash
cd terraform && terraform destroy -auto-approve  && sleep 10s && terraform init -upgrade && terraform plan -out swarm.plan &&  terraform apply swarm.plan && sleep 60s && cd ../ansible && ./generate_inventory.sh default && export ANSIBLE_HOST_KEY_CHECKING=false && ansible-playbook -i default.inventory.ini dokploy.yml -u ubuntu --private-key ~/.ssh/oci_key && cd ..
```

### 6. Test your endpoints

That's it. Now you can access your services using IP of any node from the swarm. 

> *Important note*: This setup Docker Swarm won't forward user's IP to your services, to solve this you can experiment with setting up your own load balancer and reverse proxy like traefik or nginx (contributions are welcome)

Depending on playbook you selected you will be able to access different endpoints:
1. For *dokploy.yml* -> http://<public_ip>:3000 - HTTP access to Dokploy
2. For *portainer_stack.yml* http://<public_ip>:9080 - HTTP access to Portainer
3. For *portainer_stack.yml* https://<public_ip>:9443 - HTTPS access to Portainer
4. For *mongo_stack.yml* mongodb://root:mongo_root_password@<public_ip>:27017/ - MongoDB connection string


## Troubleshooting

### Can't join worker nodes to swarm / Can't connect to endpoint
If you for some reason want to do setup of instances manually without Ansible Playbook - you will need to clean IP tables to allow traffic to ports other than 22:
1. Remove iptables-persistent with `sudo apt remove iptables-persistent`
2. Delete all existing iptables rules with `sudo iptables -F`
3. List current iptables rules with `sudo iptables -L -n -v` to make sure the previous step was successful. All chains should show `ACCEPT` policies.
4. (Optional) now you can install and configure your own firewall, e.g. UFW


---

This setup gives you **one-click reproducible clusters** with version-controlled infrastructure and configuration. Perfect for testing upgrades, disaster recovery drills, and environment consistency.