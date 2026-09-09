resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.project_name}-${var.environment}-ecs-tasks-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "From the ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    # Outbound to the internet (via the VPC's NAT gateway) for Anthropic,
    # Voyage, and Cognito calls, plus RDS/SQS within the VPC.
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}-${var.environment}-backend"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/${var.project_name}-${var.environment}-worker"
  retention_in_days = 30
}

locals {
  db_secret_arn = aws_db_instance.main.master_user_secret[0].secret_arn

  # RDS's managed-master-password secret is JSON ({"username": ..., "password": ...}),
  # not a connection string — ECS can inject a single JSON key from a secret
  # via the ":key::" suffix, so DB_USER/DB_PASSWORD come from there while
  # host/port/name are plain (non-secret) env vars. env.ts assembles the
  # full connection string from these parts at boot.
  shared_secrets = [
    { name = "ANTHROPIC_API_KEY", valueFrom = aws_secretsmanager_secret.anthropic_api_key.arn },
    { name = "VOYAGE_API_KEY", valueFrom = aws_secretsmanager_secret.voyage_api_key.arn },
    { name = "DB_USER", valueFrom = "${local.db_secret_arn}:username::" },
    { name = "DB_PASSWORD", valueFrom = "${local.db_secret_arn}:password::" },
  ]
  shared_env = [
    { name = "NODE_ENV", value = var.environment == "production" ? "production" : "development" },
    { name = "COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.main.id },
    { name = "COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.ios.id },
    { name = "COGNITO_REGION", value = var.aws_region },
    { name = "DB_HOST", value = aws_db_instance.main.address },
    { name = "DB_PORT", value = "5432" },
    { name = "DB_NAME", value = aws_db_instance.main.db_name },
    { name = "SQS_QUEUE_URL", value = aws_sqs_queue.session_summarization.url },
  ]
}

# --- API service (behind the ALB) ---

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-${var.environment}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name         = "backend"
      image        = var.container_image
      essential    = true
      portMappings = [{ containerPort = 8080, protocol = "tcp" }]
      environment  = local.shared_env
      secrets      = local.shared_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "backend"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-${var.environment}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1 # at least one task warm at all times, protects urge-surfing latency
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.http]

  lifecycle {
    # GitHub Actions updates the running image via `aws ecs update-service
    # --force-new-deployment` after pushing to ECR — don't fight that by
    # reverting to var.container_image's placeholder on every apply.
    ignore_changes = [task_definition]
  }
}

# --- Worker service (no load balancer, consumes the SQS queue) ---

resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.project_name}-${var.environment}-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name        = "worker"
      image       = var.container_image
      essential   = true
      command     = ["node", "dist/worker.js"]
      environment = local.shared_env
      secrets     = local.shared_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.worker.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "worker"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "worker" {
  name            = "${var.project_name}-${var.environment}-worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}
