#!/bin/bash

# Get Terraform outputs
cd ../terraform

# Extract public and private IPs
PUBLIC_IPS=($(terraform output -json instance_public_ips | jq -r '.[]'))
PRIVATE_IPS=($(terraform output -json instance_private_ips | jq -r '.[]'))

# Generate inventory.ini with private IPs
echo "[manager]" > ../ansible/inventory.ini
echo "${PUBLIC_IPS[0]} private_ip=${PRIVATE_IPS[0]}" >> ../ansible/inventory.ini

echo -e "\n[workers]" >> ../ansible/inventory.ini
for i in "${!PUBLIC_IPS[@]}"; do
  if [ $i -ne 0 ]; then
    echo "${PUBLIC_IPS[$i]} private_ip=${PRIVATE_IPS[$i]}" >> ../ansible/inventory.ini
  fi
done

echo "Generated inventory.ini:"
cat ../ansible/inventory.ini
