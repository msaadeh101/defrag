resource "aws_dynamodb_table" "sessions" {
  name           = "user-sessions"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "sessionId"
  
  attribute {
    name = "sessionId"
    type = "S"
  }
  
  attribute {
    name = "userId"
    type = "S"
  }
  
  global_secondary_index {
    name            = "UserIdIndex"
    hash_key        = "userId"
    projection_type = "ALL"
  }
  
  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }
  
  point_in_time_recovery {
    enabled = true
  }
  
  server_side_encryption {
    enabled = true
  }
}