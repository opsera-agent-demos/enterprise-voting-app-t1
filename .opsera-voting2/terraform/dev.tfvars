################################################################################
# Development Environment Variables (IRSA Enabled - No Credentials)
################################################################################

app_name    = "voting2"
environment = "dev"
aws_region  = "us-west-2"
tenant      = "opsera"

# VPC
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-west-2a", "us-west-2b"]

# EKS
eks_cluster_version    = "1.29"
eks_node_instance_type = "t3.medium"
eks_desired_capacity   = 2

# RDS PostgreSQL (dev sizing) - Uses IAM Authentication, no password needed
rds_instance_class    = "db.t3.micro"
rds_allocated_storage = 20

# ElastiCache Redis (dev sizing)
elasticache_node_type       = "cache.t3.micro"
elasticache_num_cache_nodes = 1

# GitHub Repository (for OIDC)
github_org  = "opsera-agentic"
github_repo = "enterprise-voting-app-t1"
