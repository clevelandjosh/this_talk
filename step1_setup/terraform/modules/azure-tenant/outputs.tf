output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "virtual_network_name" {
  value = azurerm_virtual_network.main.name
}

output "virtual_network_id" {
  value = azurerm_virtual_network.main.id
}

output "vnet_address_space" {
  value = var.vnet_address_space
}

output "subnet_id" {
  value = azurerm_subnet.main.id
}

output "subnet_address_prefix" {
  value = local.subnet_cidr
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}
