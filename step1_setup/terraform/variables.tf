variable "arm_client_id" {}
variable "arm_client_secret" {}
variable "arm_subscription_id" {}
variable "arm_tenant_id" {}

variable "location" {
  default = "eastus"
}

variable "resource_prefix" {
  default = "secconf"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network (CIDR notation)"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vnet_address_space, 0))
    error_message = "The vnet_address_space must be a valid CIDR block (e.g., 10.0.0.0/16)."
  }
}

variable "admin_email" {}
variable "admin_username" {
  default = "azureadmin"
}
variable "admin_password" {}

variable "mcp_server_count" {
  default = 2
}

variable "jira_admin_email" {}
variable "crowdstrike_api_key" {}
