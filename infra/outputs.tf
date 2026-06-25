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

# ============================================================================
# DMS Serverless outputs
# ============================================================================

output "dms_replication_config_arn" {
  description = "ARN of the DMS Serverless replication config"
  value       = try(module.dms_serverless[0].replication_config_arn, null)
}

output "dms_replication_config_id" {
  description = "ID of the DMS Serverless replication config"
  value       = try(module.dms_serverless[0].replication_config_id, null)
}

output "dms_replication_config_identifier" {
  description = "Identifier (name) of the DMS Serverless replication config"
  value       = try(module.dms_serverless[0].replication_config_identifier, null)
}

output "dms_source_endpoint_arn" {
  description = "ARN of the DMS source endpoint (Aurora PostgreSQL)"
  value       = try(module.dms_serverless[0].source_endpoint_arn, null)
}

output "dms_target_endpoint_arn" {
  description = "ARN of the DMS target endpoint (S3 Parquet)"
  value       = try(module.dms_serverless[0].target_endpoint_arn, null)
}

output "dms_security_group_id" {
  description = "DMS Serverless security group ID"
  value       = try(module.dms_serverless[0].dms_security_group_id, null)
}
