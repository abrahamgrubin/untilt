resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.environment}-rds-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Postgres from the ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Postgres 16 (RDS supports the pgvector `vector` extension from 15.2+;
# CREATE EXTENSION happens in the app's migration, not here — pgvector
# doesn't require anything in the parameter group).
resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-${var.environment}"
  engine         = "postgres"
  engine_version = "16.4"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100 # storage autoscaling ceiling
  storage_type          = "gp3"
  storage_encrypted     = true # KMS, PRD Section 9 encryption-at-rest requirement

  db_name  = "untilt"
  username = "untilt_admin"
  # RDS-managed master password: stored in its own Secrets Manager secret
  # automatically, never passed through Terraform state as plaintext.
  manage_master_user_password = true

  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az                  = var.environment == "production"
  backup_retention_period   = 7
  deletion_protection       = var.environment == "production"
  skip_final_snapshot       = var.environment != "production"
  final_snapshot_identifier = var.environment == "production" ? "${var.project_name}-${var.environment}-final" : null
}
