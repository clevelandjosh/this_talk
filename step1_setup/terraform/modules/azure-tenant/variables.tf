variable "location" {
  description = "Azure region to deploy resources"
  type        = string
}

variable "resource_prefix" {
  description = "Prefix for naming Azure resources"
  type        = string
}

variable "admin_email" {
  description = "Administrator email for notifications or identity setup"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the virtual network (CIDR notation)"
  type        = string
  
  validation {
    condition     = can(cidrhost(var.vnet_address_space, 0))
    error_message = "The vnet_address_space must be a valid CIDR block (e.g., 10.0.0.0/16)."
  }
}
