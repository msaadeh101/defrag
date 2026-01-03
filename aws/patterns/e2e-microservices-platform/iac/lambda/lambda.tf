resource "aws_lambda_function" "s3_processor" {
  filename         = "s3-processor.jar"
  function_name    = "s3-file-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "com.mycomp.S3EventHandler::handleRequest"
  runtime         = "java17"
  timeout         = 60
  memory_size     = 512

  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.file_processing.url
    }
  }

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.uploads.arn
}

resource "aws_s3_bucket_notification" "upload_notification" {
  bucket = aws_s3_bucket.uploads.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
    filter_suffix       = ".csv"
  }
}