output "apim_id" {
  description = "ID of the API Management instance."
  value       = azurerm_api_management.apim.id
}

output "apim_name" {
  description = "Name of the API Management instance."
  value       = azurerm_api_management.apim.name
}

output "apim_gateway_url" {
  description = "Gateway URL of the APIM instance."
  value       = azurerm_api_management.apim.gateway_url
}
