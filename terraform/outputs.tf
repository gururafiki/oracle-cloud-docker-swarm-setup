output "instance_public_ips" {
  value = oci_core_instance.node[*].public_ip
}

output "instance_private_ips" {
  value = oci_core_instance.node[*].private_ip
}

