terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}

  client_id       = var.arm_client_id
  client_secret   = var.arm_client_secret
  subscription_id = var.arm_subscription_id
  tenant_id       = var.arm_tenant_id
}

# Azure Tenant Setup
module "azure_tenant" {
  source = "./modules/azure-tenant"

  location         = var.location
  resource_prefix  = var.resource_prefix
  admin_email      = var.admin_email
}

# MCP Servers
module "mcp_servers" {
  source = "./modules/mcp-servers"

  location         = var.location
  resource_group   = module.azure_tenant.resource_group_name
  server_count     = var.mcp_server_count
  admin_username   = var.admin_username
  admin_password   = var.admin_password
}

# Demo Jira App
module "jira_demo" {
  source = "./modules/demo-apps/jira"

  location         = var.location
  resource_group   = module.azure_tenant.resource_group_name
  admin_email      = var.jira_admin_email
}

# Demo Crowdstrike App
module "crowdstrike_demo" {
  source = "./modules/demo-apps/crowdstrike"

  location         = var.location
  resource_group   = module.azure_tenant.resource_group_name
  api_key          = var.crowdstrike_api_key
}
