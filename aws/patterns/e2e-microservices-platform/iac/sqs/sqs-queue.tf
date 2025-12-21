resource "aws_sqs_queue" "file_processing" {
  name                       = "file-processing-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600 # 14 days
  delay_seconds             = 0
  receive_wait_time_seconds = 10 # Long polling
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.file_processing_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "file_processing_dlq" {
  name                      = "file-processing-dlq"
  message_retention_seconds = 1209600
}

# Allow Lambda to send messages
resource "aws_iam_role_policy" "lambda_sqs" {
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:GetQueueUrl"
      ]
      Resource = aws_sqs_queue.file_processing.arn
    }]
  })
}