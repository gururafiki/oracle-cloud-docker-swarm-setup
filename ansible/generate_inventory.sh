#!/bin/bash

# Get Terraform outputs
cd ../terraform

terraform workspace select $1
# Extract public and private IPs
PUBLIC_IPS=($(terraform output -json instance_public_ips | jq -r '.[]'))
PRIVATE_IPS=($(terraform output -json instance_private_ips | jq -r '.[]'))

# Generate inventory with private IPs
echo "[manager]" > ../ansible/$1.inventory.ini
echo "${PUBLIC_IPS[0]} private_ip=${PRIVATE_IPS[0]}" >> ../ansible/$1.inventory.ini

echo -e "\n[workers]" >> ../ansible/$1.inventory.ini
for i in "${!PUBLIC_IPS[@]}"; do
  if [ $i -ne 0 ]; then
    echo "${PUBLIC_IPS[$i]} private_ip=${PRIVATE_IPS[$i]}" >> ../ansible/$1.inventory.ini
  fi
done

echo "Generated $1.inventory.ini:"
cat ../ansible/$1.inventory.ini
