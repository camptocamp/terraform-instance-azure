output "this_azurerm_public_ip_ip_address" {
  value = azurerm_public_ip.this[*].ip_address
}

output "this_azurerm_network_interface_private_ip_address" {
  value = azurerm_network_interface.this[*].private_ip_address
}

######
# API

output "this_instance_public_ipv4" {
  description = "Instance's public IPv4"
  value       = length(split(":", azurem_public_ip.this[*].ip_address)) == 1 ? azurem_public_ip.this[*].ip_address : ""
}

output "this_instance_public_ipv6" {
  description = "Instance's public IPv6"
  value       = length(split(":", azurem_public_ip.this[*].ip_address)) > 1 ? azurem_public_ip.this[*].ip_address : ""
}

output "this_instance_hostname" {
  description = "Instance's hostname"
  value       = format("ip-%s.%s", join("-", split(".", azurerm_network_interface.this[count.index].private_ip_address)), var.domain)
}
