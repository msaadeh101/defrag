module "account_request" {
  source  = "aws-ia/control_tower_account_factory/aws"
  version = "1.0.1"  # Use the latest stable version

  account_name              = "my-new-account"
  account_email             = "admin@example.com"
  organizational_unit       = "Production"          # Use OU name, not ID
  account_customizations_name = "PRODUCTION"        # Must match a defined customization category
  account_type              = "Custom"              # Or "Standard" if using Control Tower defaults
  tags = {
    Environment = "Production"
    Team        = "DevOps"
  }
  ssm_parameter_prefix      = "/aft/account/customizations" # Optional: if using customizations via SSM
}
