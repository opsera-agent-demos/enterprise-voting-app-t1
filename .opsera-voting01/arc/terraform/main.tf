# ════════════════════════════════════════════════════════════════════════════════
# ACTIONS RUNNER CONTROLLER - IRSA Role
# AWS permissions for self-hosted GitHub Actions runners
# ════════════════════════════════════════════════════════════════════════════════

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "opsera-terraform-state-usw2"
    region = "us-west-2"
    # key set via -backend-config
  }
}

provider "aws" {
  region = var.aws_region
}

# ════════════════════════════════════════════════════════════════════════════════
# DATA SOURCES
# ════════════════════════════════════════════════════════════════════════════════

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "hub" {
  name = var.hub_cluster_name
}

# ════════════════════════════════════════════════════════════════════════════════
# IRSA ROLE FOR ARC RUNNERS
# Allows runners to interact with AWS services
# ════════════════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "arc_runner" {
  name = "${var.app_name}-arc-runner-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.hub.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.hub.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:actions-runner-system:arc-runner"
            "${replace(data.aws_eks_cluster.hub.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Application = var.app_name
    Component   = "arc-runner"
    ManagedBy   = "terraform"
  }
}

# ════════════════════════════════════════════════════════════════════════════════
# IAM POLICY - ECR Access
# Push/pull images to ECR
# ════════════════════════════════════════════════════════════════════════════════

resource "aws_iam_role_policy" "arc_ecr" {
  name = "${var.app_name}-arc-ecr-policy"
  role = aws_iam_role.arc_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/opsera/${var.app_name}-*"
      }
    ]
  })
}

# ════════════════════════════════════════════════════════════════════════════════
# IAM POLICY - EKS Access
# Update kubeconfig and access clusters
# ════════════════════════════════════════════════════════════════════════════════

resource "aws_iam_role_policy" "arc_eks" {
  name = "${var.app_name}-arc-eks-policy"
  role = aws_iam_role.arc_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# ════════════════════════════════════════════════════════════════════════════════
# IAM POLICY - Secrets Manager Access
# Read database credentials
# ════════════════════════════════════════════════════════════════════════════════

resource "aws_iam_role_policy" "arc_secrets" {
  name = "${var.app_name}-arc-secrets-policy"
  role = aws_iam_role.arc_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.app_name}/*"
      }
    ]
  })
}
