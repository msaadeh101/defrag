variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
}

variable "location" {
  description = "Azure region for APIM."
  type        = string
}

variable "apim_name" {
  description = "Name of the APIM instance."
  type        = string
}

variable "publisher_name" {
  description = "The name of the APIM publisher."
  type        = string
}

variable "publisher_email" {
  description = "The email of the APIM publisher."
  type        = string
}

variable "sku_name" {
  description = "APIM SKU (e.g., Developer, Standard, Premium)."
  type        = string
  default     = "Developer"
}

variable "custom_domain_enabled" {
  description = "Enable custom domain for APIM."
  type        = bool
  default     = false
}

variable "custom_domain_name" {
  description = "Custom domain name for APIM."
  type        = string
  default     = ""
}

variable "key_vault_certificate_id" {
  description = "Azure Key Vault certificate ID for APIM custom domain."
  type        = string
  default     = ""
}

variable "app_insights_enabled" {
  description = "Enable Application Insights for APIM."
  type        = bool
  default     = false
}

variable "app_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights."
  type        = string
  default     = ""
}

variable "enable_monitoring" {
  description = "Enable diagnostic logs and metrics for APIM."
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for APIM monitoring."
  type        = string
  default     = ""
}
