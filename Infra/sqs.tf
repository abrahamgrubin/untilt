# Session-end summarization job queue (PRD 13.3 / architecture doc Section 5)
# — replaces the in-process fire-and-forget implementation from the data-
# layer step. Consumed by the worker service in ecs.tf.

resource "aws_sqs_queue" "session_summarization_dlq" {
  name                      = "${var.project_name}-${var.environment}-session-summarization-dlq"
  message_retention_seconds = 1209600 # 14 days — long enough to investigate and replay failures
}

resource "aws_sqs_queue" "session_summarization" {
  name                       = "${var.project_name}-${var.environment}-session-summarization"
  visibility_timeout_seconds = 60 # should comfortably exceed one summarization job's processing time
  message_retention_seconds  = 86400

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.session_summarization_dlq.arn
    maxReceiveCount     = 5
  })
}
