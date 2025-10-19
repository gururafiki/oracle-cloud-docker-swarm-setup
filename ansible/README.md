## ⚙️ Ansible Configuration Overview

### File Structure
```bash
ansible/
├── *.yml                    # Ansible Playbooks
├── roles/tasks/main.yml     # Re-usable roles to build your own Playbooks
├── roles/handlers/main.yml  # Re-usable handlers to include in your own Playbooks
├── dokploy/scripts/         # Scripts required to setup dokploy remote servers
└── generate_inventory.sh    # Bash script for inventory generation
```

### *generate_inventory.sh* - Inventory generation script
We will use this script to read terraform outputs and convert them to *inventory.ini* file(s) that can be used by Anisble Playbook.

> *Note*: Terraform has a plugin for Ansible: https://registry.terraform.io/providers/ansible/ansible/latest and Ansible has a plugin for terraform. Process of generating inventory for Ansible can be further automated. Contributions are welcome :D

### Common setup accross all playbooks:
- Securing SSH (currently it's enabling root login, as it's needed for Dokploy remote servers, however this can be adjused for better security if you are not going to deploy Dokploy - check *roles/ssh/tasks/main.yml*)
- Setting up [Fail2Ban](https://github.com/fail2ban/fail2ban)
- Setting up [UFW](https://en.wikipedia.org/wiki/Uncomplicated_Firewall)
- Setting up `iptables` for Docker Swarm communication within Oracle Cloud
- Installing Docker
- Initializing Docker Swarm (1 Manager and N Workers)

### Assumptions with these playbooks:
- You deploy them to Oracle Cloud Infrastructure instances
- You use Ubuntu Operating System

### Available playbooks:

#### (Recommended for start) 0. Docker Swarm Cluster with Portainer service - *portainer_stack.yml*
Simple playbook to create:
- Docker Swarm cluster with 1 manager and N workers.
- Portainer Service deployed to Docker Swarm cluster

[More details](../docker-stack/templates/portainer/README.md)

##### Why is this playbook here?
This playbook is a good start as it provides clean Docker Swarm cluster with Portainer that can help you monitor and configure your swarm from Web UI.

#### 1. Dokploy and Remote Docker Swarm Cluster - *dokploy.yml*
Simple playbook to create:
- Docker Swarm with 1 manager and N workers
- Dokploy Service deployed to Docker Swarm Cluster

After running this playbook - you will be able to access Dokploy from your browser. Navigate to `http://<public_ip>:3000`. After creating account you will need to:
* Create Docker Registry 
* Add SSH Key
* (if you want to host apps within Dokploy cluster) - Register cluster
* (if you want to use separate from Dokploy instance cluster for your apps) - Add Remote Server (Create Docker Swarm Cluster as a Remote server for Dokploy using playbook below, keep in mind - you will need separate inventory with separate set of instances for it)

##### Why is this playbook here?
This playbook provides comprehensive setup to start developing services in your new Docker Swarm. Dokploy is powerful solution with tons of templates and integration with GitHub that will allow you convert your ideas to production-ready solutions. Keep in-mind that commercial use of Dokploy is subject to [Dokploy License](https://github.com/Dokploy/dokploy/blob/canary/LICENSE.MD)

#### 1.1. Docker Swarm Cluster as a Remote server for Dokploy - *dokploy_remote_swarm.yml*
Simple playbook to create:
- Docker Swarm cluster with 1 manager and N workers.

##### Why is this playbook here?
This playbook provides clean Docker Swarm cluster without any services that can be used as remote server for Dokploy.

#### 2. Dokploy Docker Swarm Cluster - *dokploy_stack.yml*
Simple playbook to create:
- Dokploy Cluster (Docker Swarm based) with 1 manager and N workers.

After running this playbook - you will be able to access Dokploy, it assumes that you don't need Dokploy Remote Servers, so you don't need extra setup after creation of account in Dokploy.

[More details](../docker-stack/templates/dokploy/README.md)

##### Why is this playbook here?
This playbook provides an example of how to set **environment variables** from template (*secrets.yaml*). This is useful for images that doesn't support Docker Secrets, so you need to provide secrets as environment variables.
```yaml
- name: Read secrets.yaml file
    include_vars:
    file: ../docker-stack/templates/dokploy/secrets.yaml
    name: secrets

- name: Copy docker-compose file
    template:
    src: ../docker-stack/templates/dokploy/docker-compose.yaml
    dest: /home/ubuntu/docker-compose.yaml
    vars:
    postgres_password: "{{ secrets.POSTGRES_PASSWORD }}"
```

#### 3. Docker Swarm Cluster with MongoDB service - *mongo_stack.yml*
Simple playbook to create:
- Docker Swarm cluster with 1 manager and N workers.
- Mongo Service deployed to Docker Swarm cluster

[More details](../docker-stack/templates/mongo/README.md)

##### Why is this playbook here?

###### 1. This playbook provides an example of how to set **docker secrets** from template (*secrets.yaml*). This is recommended way to store secrets when deploying services to Docker Swarm.
```yaml
- name: Read secrets.yaml file
    include_vars:
    file: ../docker-stack/templates/mongo/secrets.yaml
    name: secrets

- name: Check MongoDB password secret
    command: docker secret inspect mongo_root_password
    ignore_errors: yes
    register: secret_check
    changed_when: false
    
- name: Create MongoDB password secret
    shell: echo -n "{{ secrets.MONGO_ROOT_PASSWORD }}" | docker secret create mongo_root_password -
    when: secret_check.rc != 0
```

###### 2. This playbook provides an example of how to prepare files required for services on a remote host.
```yaml
- name: Copy MongoDB init script directory
    copy:
    src: ../docker-stack/templates/mongo/mongodb-init
    dest: /home/ubuntu/
```

## Step-by-step guide to setup Docker Swarm cluster using Ansible

### 1. Install Ansible
Follow [Official installation guide](https://docs.ansible.com/ansible/2.9/installation_guide/intro_installation.html)

#### Alternative for MacOS using Homebrew
```bash
brew install ansible
```

### Step 2: Verify Installation
```bash
ansible --version
# Should show: ansible [core 2.16.5]
```

### Step 4: Create inventory (*inventory.ini*)

This script has one positional argument which corresponds to terraform workspace name (default terraform workspace is called `default`)
If you want to use instances created with terraform - generate inventory from terraform outputs:
```bash
chmod +x generate_inventory.sh
./generate_inventory.sh default
```

#### Alternative is to generate *inventory.ini* for already existing instances
Example:
```ini
[manager]
123.45.67.89 private_ip=10.0.1.155

[workers]
23.45.67.89 private_ip=10.0.1.157
3.45.67.89 private_ip=10.0.1.192
123.45.67.8 private_ip=10.0.1.14

```

### (Optional: if you want to deploy *dokploy_stack.yml*) 5. Prepare docker-compose.yaml and secrets.yaml
1. Rename *../docker-stack/templates/dokploy/secrets.example.yaml* to *../docker-stack/templates/dokploy/secrets.yaml* and fill with desired values.


### (Optional: if you want to deploy *mongo_stack.yml*) 5. Prepare docker-compose.yaml and secrets.yaml
1. Rename *../docker-stack/templates/mongo/secrets.example.yaml* to *../docker-stack/templates/mongo/secrets.yaml* and fill with desired values.
2. Update *../docker-stack/templates/mongo/mongodb-init/mongo-init.js* to strong password for user we are going to create. (TODO: this should be moved to secrets as well, contributions are welcome)


### 6. Run Ansible Playbook

> *Imporant*: if you haven't connected to instances before over SSH - you may need to approve that you want to connect to unknown host. This can be mitigated by setting env variable: `ANSIBLE_HOST_KEY_CHECKING=false` or creating/updating `~/.ansible.cfg` with `host_key_checking = False`.
> *Important*: `<ssh_private_key_path>` should point to private key that is that pair for `ssh_public_key_path` from terraform configuration.

```bash
ansible-playbook -i default.inventory.ini <selected_playbook.yml> -u <user> --private-key <ssh_private_key_path>
cd ..
```
e.g.
```bash
export ANSIBLE_HOST_KEY_CHECKING=false && ansible-playbook -i default.inventory.ini portainer_stack.yml -u ubuntu --private-key ~/.ssh/oci_key
cd ..
```