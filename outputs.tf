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
  value = [
    for i in range(length(azurerm_public_ip.this[*])) :
    length(split(":", azurerm_public_ip.this[i].ip_address)) == 1 ? azurerm_public_ip.this[i].ip_address : ""
  ]
}

output "this_instance_public_ipv6" {
  description = "Instance's public IPv6"
  value       = length(split(":", azurerm_public_ip.this[*].ip_address)) > 1 ? azurerm_public_ip.this[*].ip_address : []
}

output "this_instance_hostname" {
  description = "Instance's hostname"
  value       = format("ip-%s.%s", join("-", split(".", azurerm_network_interface.this[*].private_ip_address)), var.domain)
}
