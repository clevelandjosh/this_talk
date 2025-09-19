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
