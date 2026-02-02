# ════════════════════════════════════════════════════════════════════════════════
# VARIABLES - ARC Runner IRSA
# ════════════════════════════════════════════════════════════════════════════════

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "voting01"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "hub_cluster_name" {
  description = "EKS hub cluster name (where ArgoCD and ARC run)"
  type        = string
  default     = "argocd-usw2"
}
