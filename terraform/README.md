## Step-by-step guide to create instances in Oracle Cloud using Terraform

### 1. Install Terraform

Follow [Official guide to install Terraform](https://developer.hashicorp.com/terraform/install)

#### Example for MacOS using Homebrew

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

#### Verify Installation
```bash
terraform version
# Should show: Terraform v1.7.0

# Initialize Terraform
terraform init
```

#### Troubleshooting
If are getting "command not found", make sure that `/usr/local/bin` is added to `PATH` and restart terminal:
```bash
# Add to PATH
echo 'export PATH="$PATH:/usr/local/bin"' >> ~/.zshrc # or ~/.bashrc depending on what you are using
source ~/.zshrc
```

### 2. Rename *terraform.example.tfvars* to *terraform.tfvars*

### 3. Obtain Terraform Variables to fill missing values in *terraform.tfvars* 

#### 1. Tenancy and User OCIDs
- **tenancy_ocid**: 
  1. Go to OCI Console > Administration > Tenancy Details
  2. Copy "OCID" under "Tenancy Information"
- **user_ocid**:
  1. Navigate to Identity > Users
  2. Select your user > Copy "OCID"

#### 2. API Key Credentials
- **private_key_path**:
  1. Generate API key: Identity > Users > Your User > API Keys > Add API Key
  2. Download private key (saves as .pem file)
  3. Note path to downloaded file (e.g., ~/.oci/oci_api_key.pem)
- **fingerprint**:
  1. After API key generation, copy the fingerprint shown in console

#### 3. Region Identifier
- **region**:
  1. Check current region in top-right corner of OCI console
  2. Use region identifier (e.g., us-phoenix-1, uk-london-1)

#### 4. Compartment OCID
- **compartment_ocid**:
  1. Go to Identity > Compartments
  2. Select your compartment > Copy "OCID"

#### 5. SSH Public Key
- **ssh_public_key_path**:
  1. Use existing key (e.g., ~/.ssh/id_rsa.pub)
  2. Or generate new key:
     ```bash
     ssh-keygen -t rsa -b 4096 -f ~/.ssh/oci_key
     ```

#### 6. (Optional) Update Operating system

We are using `operating_system = "Canonical Ubuntu"`, you can try `operating_system = "Oracle Linux"` or any other opearting system that meets your needs.

#### 7. (Optional) Update instance configuration to spin up 4 ARM instances instead of 2 AMD instances

> *Important*: ARM based instances are hard to get due to limited capacity with Free tier accounts. In order to solve this problem you can create simple script to apply terraform in loop or upgrade your Account to *Pay As You Go* plan.

Use configuration below to acquire 4 instances with ARM chip:
```hcl
availability_domain = 0
shape = "VM.Standard.A1.Flex"
node_count = 4
ocpus = 1
memory_in_gbs = 6
```

> *Important*: Make sure that selected `availability_domain` allows you to create instance with shape you've selected. You can check it in Oracle Cloud Web UI when creating instance manually or using `oci` command-line tool (contribution to this repo with guide on using `oci` is welcome).

#### Example *terraform.tfvars*
```hcl
# Oracle Cloud Configuration
tenancy_ocid = "ocid1.tenancy.oc1..aaaaaaa..."
user_ocid = "ocid1.user.oc1..aaaaaaa..."
private_key_path = "~/.oci/oci_api_key.pem"
fingerprint = "12:34:56:78:90:ab:cd:ef:12:34:56:78:90:ab:cd:ef"
region = "us-phoenix-1"

# Compartment OCID
compartment_ocid = "ocid1.compartment.oc1..aaaaaaa..."

# SSH Public Key Path
ssh_public_key_path = "~/.ssh/id_rsa.pub" # or "~/.ssh/oci_key.pub" if was generated using example above

# Instances configuration
name_prefix = "docker-swarm"
operating_system = "Canonical Ubuntu"
availability_domain = 0
shape = "VM.Standard.E2.1.Micro"
node_count = 2
ocpus = 1
memory_in_gbs = 1
```

### 3. 🚀 Deployment Workflow

> **Important**: Replace placeholder values in *terraform.tfvars* with your actual credentials before deploying.

```bash
terraform init
terraform plan -out swarm.plan
terraform apply swarm.plan
```

