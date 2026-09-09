resource "aws_secretsmanager_secret" "anthropic_api_key" {
  name = "${var.project_name}/${var.environment}/anthropic-api-key"
}
resource "aws_secretsmanager_secret_version" "anthropic_api_key" {
  secret_id     = aws_secretsmanager_secret.anthropic_api_key.id
  secret_string = var.anthropic_api_key
}

resource "aws_secretsmanager_secret" "voyage_api_key" {
  name = "${var.project_name}/${var.environment}/voyage-api-key"
}
resource "aws_secretsmanager_secret_version" "voyage_api_key" {
  secret_id     = aws_secretsmanager_secret.voyage_api_key.id
  secret_string = var.voyage_api_key
}
# Database credentials: handled by RDS's manage_master_user_password
# (see rds.tf) — that secret is aws_db_instance.main.master_user_secret[0].secret_arn,
# no separate resource needed here.
