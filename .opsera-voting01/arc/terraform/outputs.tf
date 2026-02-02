# ════════════════════════════════════════════════════════════════════════════════
# OUTPUTS - ARC Runner IRSA
# ════════════════════════════════════════════════════════════════════════════════

output "arc_runner_role_arn" {
  description = "IAM role ARN for ARC runners"
  value       = aws_iam_role.arc_runner.arn
}

output "arc_runner_role_name" {
  description = "IAM role name for ARC runners"
  value       = aws_iam_role.arc_runner.name
}
