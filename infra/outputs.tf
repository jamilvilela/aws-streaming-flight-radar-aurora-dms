# ============================================================================
# Aurora Serverless v2 outputs
# ============================================================================

output "aurora_endpoint" {
  description = "Aurora Serverless v2 cluster writer endpoint address"
  value       = module.aurora_postgres.db_endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora Serverless v2 cluster reader endpoint address"
  value       = module.aurora_postgres.db_reader_endpoint
}

output "aurora_port" {
  description = "Aurora Serverless v2 cluster port"
  value       = module.aurora_postgres.db_port
}

output "aurora_db_name" {
  description = "Aurora Serverless v2 database name"
  value       = module.aurora_postgres.db_name
}

output "aurora_cluster_arn" {
  description = "ARN of the Aurora cluster"
  value       = module.aurora_postgres.cluster_arn
}

output "aurora_security_group_id" {
  description = "Aurora Serverless v2 security group ID"
  value       = module.aurora_postgres.security_group_id
}

output "aurora_connection" {
  description = "Aurora connection string for psql"
  value       = module.aurora_postgres.aurora_connection
  sensitive   = true
}

output "aurora_admin_username" {
  description = "Aurora Serverless v2 admin username"
  value       = module.aurora_postgres.admin_username
  sensitive   = true
}


