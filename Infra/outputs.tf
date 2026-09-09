output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_client_id" {
  value = aws_cognito_user_pool_client.ios.id
}

output "cognito_hosted_ui_domain" {
  value = "${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "rds_endpoint" {
  value = aws_db_instance.main.address
}

output "rds_credentials_secret_arn" {
  description = "Secrets Manager secret holding the RDS master username/password"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "sqs_queue_url" {
  value = aws_sqs_queue.session_summarization.url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}
