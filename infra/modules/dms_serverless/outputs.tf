output "replication_config_arn" {
  description = "ARN of the DMS Serverless replication config"
  value       = aws_dms_replication_config.this.arn
}

output "replication_config_id" {
  description = "Identifier of the DMS Serverless replication config"
  value       = aws_dms_replication_config.this.id
}

output "source_endpoint_arn" {
  description = "ARN of the DMS source endpoint (Aurora PostgreSQL)"
  value       = aws_dms_endpoint.source.endpoint_arn
}

output "target_endpoint_arn" {
  description = "ARN of the DMS target endpoint (S3 Parquet)"
  value       = aws_dms_s3_endpoint.target.endpoint_arn
}

output "replication_config_identifier" {
  description = "Identifier (name) of the DMS Serverless replication config (for CloudWatch metrics)"
  value       = aws_dms_replication_config.this.replication_config_identifier
}

output "dms_security_group_id" {
  description = "DMS Serverless security group ID"
  value       = aws_security_group.dms.id
}
