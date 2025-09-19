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
