# ============================================================================
# Aurora Serverless v2 outputs
# ============================================================================

output "aurora_endpoint" {
  description = "Aurora Serverless v2 cluster writer endpoint address"
  value       = aws_rds_cluster.this.endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora Serverless v2 cluster reader endpoint address"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "aurora_port" {
  description = "Aurora Serverless v2 cluster port"
  value       = aws_rds_cluster.this.port
}

output "aurora_db_name" {
  description = "Aurora Serverless v2 database name"
  value = var.aurora_config.db_name != null && var.aurora_config.db_name != "" ? var.aurora_config.db_name : "flightradar"
}

output "aurora_cluster_arn" {
  description = "ARN of the Aurora cluster"
  value       = aws_rds_cluster.this.arn
}

output "aurora_security_group_id" {
  description = "Aurora Serverless v2 security group ID"
  value       = aws_security_group.aurora.id
}

output "aurora_connection" {
  description = "Aurora connection string for psql"
  value       = "postgresql://${local.effective_admin_username}@${aws_rds_cluster.this.endpoint}:${aws_rds_cluster.this.port}/${aws_rds_cluster.this.database_name}"
  sensitive   = true
}

output "aurora_admin_username" {
  description = "Aurora Serverless v2 admin username"
  value       = local.effective_admin_username
  sensitive   = true
}


