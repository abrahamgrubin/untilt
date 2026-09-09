# Identity: Apple SSO (existing), Google SSO (new), and local email/password
# accounts, all issuing a uniform token the backend verifies with one
# middleware (see Server/src/middleware/auth.ts). Implements ADR 0003.

resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-${var.environment}"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Journal/conversation data is HIPAA-adjacent (PRD Section 9) — advanced
  # security features add compromised-credential detection and adaptive
  # risk-based auth at the identity layer.
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }
}

resource "aws_cognito_identity_provider" "apple" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "SignInWithApple"
  provider_type = "SignInWithApple"

  provider_details = {
    client_id        = var.apple_services_id
    team_id          = var.apple_team_id
    key_id           = var.apple_key_id
    private_key      = var.apple_private_key
    authorize_scopes = "email name"
  }

  attribute_mapping = {
    email    = "email"
    username = "sub"
  }

  # AWS populates several additional provider_details keys server-side
  # (e.g. attributes_url_add_attributes, oidc_issuer) beyond what we
  # declare — without this, every subsequent plan shows a phantom diff
  # trying to strip AWS's own defaults back out.
  lifecycle {
    ignore_changes = [provider_details]
  }
}

resource "aws_cognito_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id        = var.google_client_id
    client_secret    = var.google_client_secret
    authorize_scopes = "email profile openid"
  }

  attribute_mapping = {
    email    = "email"
    username = "sub"
  }

  lifecycle {
    ignore_changes = [provider_details]
  }
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id
}

resource "aws_cognito_user_pool_client" "ios" {
  name         = "${var.project_name}-ios"
  user_pool_id = aws_cognito_user_pool.main.id

  # Native mobile app: no client secret (PKCE via ASWebAuthenticationSession
  # for the federated flows; SRP for local email/password).
  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  supported_identity_providers = [
    "COGNITO", # local email/password
    aws_cognito_identity_provider.apple.provider_name,
    aws_cognito_identity_provider.google.provider_name,
  ]

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  # Custom URL scheme redirect back into the iOS app after a federated
  # sign-in. Confirm this matches whatever's registered in the Xcode
  # project's URL Types.
  callback_urls = ["untilt://auth-callback"]
  logout_urls   = ["untilt://auth-logout"]

  access_token_validity  = 1  # hours
  refresh_token_validity = 30 # days

  token_validity_units {
    access_token  = "hours"
    refresh_token = "days"
  }
}
