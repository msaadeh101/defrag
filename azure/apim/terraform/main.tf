provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "apim" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_api_management" "apim" {
  name                = var.apim_name
  location            = azurerm_resource_group.apim.location
  resource_group_name = azurerm_resource_group.apim.name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.sku_name
}

resource "azurerm_api_management_custom_domain" "apim" {
  api_management_id = azurerm_api_management.apim.id

  gateway {
    host_name    = "api.example.com"
    key_vault_certificate_id = azurerm_key_vault_certificate.apim.versionless_secret_id
  }

  developer_portal {
    host_name    = "portal.example.com"
    key_vault_certificate_id = azurerm_key_vault_certificate.apim.versionless_secret_id
  }
}

resource "azurerm_key_vault_certificate" "apim" {
  name         = "apim-certificate"
  key_vault_id = data.azurerm_key_vault.apim.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject            = "CN=api.example.com"
      validity_in_months = 12

      subject_alternative_names {
        dns_names = [
          "api.example.com",
          "portal.example.com",
        ]
      }
    }
  }
}


resource "azurerm_api_management_logger" "apim_logger" {
  count               = var.app_insights_enabled ? 1 : 0
  name                = "appInsightsLogger"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.apim.name
  application_insights {
    instrumentation_key = var.app_insights_instrumentation_key
  }
}

resource "azurerm_monitor_diagnostic_setting" "apim_diagnostics" {
  count                      = var.enable_monitoring ? 1 : 0
  name                       = "apim-diagnostics"
  target_resource_id         = azurerm_api_management.apim.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "GatewayLogs"
  }
  enabled_metric {
    category = "AllMetrics"
  }
}
