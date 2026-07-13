output "cluster_identifier" {
  description = "Aurora cluster identifier"
  value       = aws_rds_cluster.this.id
}

output "cluster_arn" {
  description = "ARN of the Aurora cluster"
  value       = aws_rds_cluster.this.arn
}

output "db_name" {
  description = "Database name"
  # Usa o nome configurado (var.db_name) em vez do recurso real
  # para que o Batch receba o nome do banco mesmo quando o cluster
  # foi restaurado de snapshot sem database default
  value = var.db_name != null && var.db_name != "" ? var.db_name : "flightradar"
}

output "db_endpoint" {
  description = "Aurora cluster writer endpoint address"
  value       = aws_rds_cluster.this.endpoint
}

output "db_reader_endpoint" {
  description = "Aurora cluster reader endpoint address"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "db_port" {
  description = "Aurora cluster port"
  value       = aws_rds_cluster.this.port
}

output "db_hosted_zone_id" {
  description = "Route53 hosted zone ID for the endpoint"
  value       = aws_rds_cluster.this.hosted_zone_id
}

output "admin_username" {
  description = "Admin username"
  value       = var.admin_username
  sensitive   = true
}

output "security_group_id" {
  description = "Aurora security group ID"
  value       = aws_security_group.aurora.id
}

output "cluster_parameter_group_name" {
  description = "Cluster parameter group name"
  value       = aws_rds_cluster_parameter_group.this.name
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = var.create_log_group ? aws_cloudwatch_log_group.postgres[0].name : data.aws_cloudwatch_log_group.postgres.name
}

output "writer_instance_id" {
  description = "Writer RDS cluster instance identifier (for CloudWatch metrics)"
  value       = aws_rds_cluster_instance.writer.id
}

output "aurora_connection" {
  description = "Aurora connection string for psql"
  value       = "postgresql://${var.admin_username}@${aws_rds_cluster.this.endpoint}:${aws_rds_cluster.this.port}/${aws_rds_cluster.this.database_name}"
  sensitive   = true
}
