resource "aws_iam_policy" "prometheus" {
  name        = "prometheus-policy"
  description = "IAM Policy for Prometheus in EKS"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["cloudwatch:GetMetricData", "cloudwatch:GetMetricStatistics", "ec2:DescribeInstances"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "prometheus_attach" {
  role       = aws_iam_role.prometheus.name
  policy_arn = aws_iam_policy.prometheus.arn
}

resource "kubectl_manifest" "prometheus_sa" {
  yaml_body = <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
  annotations:
    eks.amazonaws.com/role-arn: ${aws_iam_role.prometheus.arn}
YAML
}

resource "aws_iam_role" "prometheus" {
  name = "eks-prometheus-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:monitoring:prometheus"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "prometheus" {
  name        = "prometheus-policy"
  description = "IAM Policy for Prometheus in EKS"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["cloudwatch:GetMetricData", "cloudwatch:GetMetricStatistics", "ec2:DescribeInstances"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "prometheus_attach" {
  role       = aws_iam_role.prometheus.name
  policy_arn = aws_iam_policy.prometheus.arn
}
