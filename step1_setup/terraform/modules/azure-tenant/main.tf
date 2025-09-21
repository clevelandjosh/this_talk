# Calculate subnet addresses based on the provided VNet address space
locals {
  # Extract the network portion and prefix length
  vnet_cidr_parts = split("/", var.vnet_address_space)
  vnet_prefix_length = tonumber(local.vnet_cidr_parts[1])
  
  # Calculate subnet CIDR (add 8 to the prefix length for /24 subnets from /16 networks)
  # This works for most common scenarios: /16 -> /24, /12 -> /20, /8 -> /16, etc.
  subnet_prefix_length = local.vnet_prefix_length + 8
  
  # Generate subnet addresses by taking the first subnet from the VNet range
  subnet_cidr = cidrsubnet(var.vnet_address_space, 8, 1)
  
  # Additional subnets can be generated if needed
  # subnet_cidr_2 = cidrsubnet(var.vnet_address_space, 8, 2)
  # subnet_cidr_3 = cidrsubnet(var.vnet_address_space, 8, 3)
}

resource "azurerm_resource_group" "main" {
  name     = "${var.resource_prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.resource_prefix}-vnet"
  address_space       = [var.vnet_address_space]
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  
  tags = {
    Purpose = "Demo environment for AI security automation"
    Project = "ISS-Talk"
  }
}

resource "azurerm_subnet" "main" {
  name                 = "${var.resource_prefix}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.subnet_cidr]
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.resource_prefix}-law"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Free"
  
  tags = {
    Purpose = "Demo environment for AI security automation"
    Project = "ISS-Talk"
  }
}
