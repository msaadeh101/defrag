resource "aws_secretsmanager_secret" "thanos_s3" {
  name = "thanos-s3-credentials"
}

resource "aws_secretsmanager_secret_version" "thanos_s3_version" {
  secret_id = aws_secretsmanager_secret.thanos_s3.id
  secret_string = jsonencode({
    bucket     = "my-thanos-metrics-bucket"
    access_key = "YOUR_AWS_ACCESS_KEY"
    secret_key = "YOUR_AWS_SECRET_KEY"
    region     = "us-east-1"
  })
}

resource "kubernetes_secret" "thanos_objstore" {
  metadata {
    name      = "thanos-objstore-secret"
    namespace = "monitoring"
  }

  data = {
    "objstore.yml" = <<EOF
type: S3
config:
  bucket: "${jsondecode(aws_secretsmanager_secret_version.thanos_s3_version.secret_string)["bucket"]}"
  endpoint: "s3.amazonaws.com"
  access_key: "${jsondecode(aws_secretsmanager_secret_version.thanos_s3_version.secret_string)["access_key"]}"
  secret_key: "${jsondecode(aws_secretsmanager_secret_version.thanos_s3_version.secret_string)["secret_key"]}"
  region: "${jsondecode(aws_secretsmanager_secret_version.thanos_s3_version.secret_string)["region"]}"
EOF
  }
}
