data "azurerm_key_vault" "apim" {
  name                = "apimkv"
  resource_group_name = "apim-resource-group"
}