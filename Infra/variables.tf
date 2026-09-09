variable "project_name" {
  type    = string
  default = "untilt"
}

variable "environment" {
  type        = string
  description = "e.g. staging, production"
  default     = "staging"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro" # cheapest ARM-based instance sufficient for early-stage load; resize as usage grows
}

# --- Secrets fed into AWS Secrets Manager (never committed; pass via
#     terraform.tfvars, which is gitignored, or TF_VAR_ environment vars) ---

variable "anthropic_api_key" {
  type      = string
  sensitive = true
}

variable "voyage_api_key" {
  type      = string
  sensitive = true
}

# --- Cognito federated identity providers ---
# These credentials come from developer consoles Terraform can't create
# resources in (Apple Developer, Google Cloud Console) — see Infra/README.md
# for the manual setup steps that produce each of these values.

variable "apple_services_id" {
  description = "The Services ID (client_id) configured for Sign in with Apple"
  type        = string
}

variable "apple_team_id" {
  type = string
}

variable "apple_key_id" {
  type = string
}

variable "apple_private_key" {
  description = "Contents of the .p8 private key from Apple Developer > Keys"
  type        = string
  sensitive   = true
}

variable "google_client_id" {
  type = string
}

variable "google_client_secret" {
  type      = string
  sensitive = true
}

# --- Backend container image ---
# First apply has nothing in ECR yet, so this defaults to a placeholder
# public image just so the ECS service can start; GitHub Actions overwrites
# it with the real build on the first successful deploy (see
# .github/workflows/backend-deploy.yml).
variable "container_image" {
  type    = string
  default = "public.ecr.aws/docker/library/hello-world:latest"
}

# --- Optional HTTPS ---
# Leave empty for an HTTP-only ALB (fine for early development). Set once
# a domain + ACM certificate exist — required before shipping, since iOS
# App Transport Security requires HTTPS.
variable "acm_certificate_arn" {
  type    = string
  default = ""
}
