# Outputs for AWS Batch Module

output "compute_environment_name" {
  description = "Nome do Compute Environment"
  value       = aws_batch_compute_environment.this.name
}

output "compute_environment_arn" {
  description = "ARN do Compute Environment"
  value       = aws_batch_compute_environment.this.arn
}

output "job_queue_name" {
  description = "Nome da Job Queue"
  value       = aws_batch_job_queue.this.name
}

output "job_queue_arn" {
  description = "ARN da Job Queue"
  value       = aws_batch_job_queue.this.arn
}

output "job_definition_historical_name" {
  description = "Nome da Job Definition para carga histórica"
  value       = aws_batch_job_definition.historical.name
}

output "job_definition_historical_arn" {
  description = "ARN da Job Definition para carga histórica"
  value       = aws_batch_job_definition.historical.arn
}

output "job_definition_stream_name" {
  description = "Nome da Job Definition para streaming CDC"
  value       = aws_batch_job_definition.stream.name
}

output "job_definition_stream_arn" {
  description = "ARN da Job Definition para streaming CDC"
  value       = aws_batch_job_definition.stream.arn
}

output "job_definition_load_reference_name" {
  description = "Nome da Job Definition para load-reference"
  value       = aws_batch_job_definition.load_reference.name
}

output "job_definition_load_reference_arn" {
  description = "ARN da Job Definition para load-reference"
  value       = aws_batch_job_definition.load_reference.arn
}

output "batch_job_role_arn" {
  description = "ARN da IAM Role para jobs"
  value       = aws_iam_role.batch_job_role.arn
}

output "batch_execution_role_arn" {
  description = "ARN da IAM Execution Role"
  value       = aws_iam_role.batch_execution_role.arn
}

output "batch_instance_profile_arn" {
  description = "ARN do Instance Profile"
  value       = aws_iam_instance_profile.batch_instance_profile.arn
}

output "log_group_name" {
  description = "Nome do CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.batch_logs.name
}

output "efs_access_point_id" {
  description = "ID do EFS Access Point"
  value       = aws_efs_access_point.batch.id
}