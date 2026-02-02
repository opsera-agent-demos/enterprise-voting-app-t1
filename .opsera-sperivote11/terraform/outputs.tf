output "ecr_vote_repository_url" {
  value = aws_ecr_repository.vote.repository_url
}

output "ecr_result_repository_url" {
  value = aws_ecr_repository.result.repository_url
}

output "ecr_worker_repository_url" {
  value = aws_ecr_repository.worker.repository_url
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  value = aws_db_instance.postgres.address
}

output "elasticache_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "irsa_vote_role_arn" {
  value = aws_iam_role.vote.arn
}

output "irsa_result_role_arn" {
  value = aws_iam_role.result.arn
}

output "irsa_worker_role_arn" {
  value = aws_iam_role.worker.arn
}

output "irsa_db_init_role_arn" {
  value = aws_iam_role.db_init.arn
}

output "rds_master_secret_arn" {
  value = aws_secretsmanager_secret.rds_master.arn
}
