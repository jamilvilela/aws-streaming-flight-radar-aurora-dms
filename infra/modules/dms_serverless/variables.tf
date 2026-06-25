variable "project_name" {
  description = "Project name used as resource prefix"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for DMS security group"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for DMS Serverless (minimum 2)"
  type        = list(string)
}

# Aurora connection info
variable "aurora_endpoint" {
  description = "Aurora cluster writer endpoint address"
  type        = string
}

variable "aurora_port" {
  description = "Aurora cluster port"
  type        = number
  default     = 5432
}

variable "aurora_db_name" {
  description = "Aurora database name"
  type        = string
}

variable "aurora_security_group_id" {
  description = "Aurora security group ID (DMS needs ingress)"
  type        = string
}

# S3 landing bucket
variable "landing_bucket_name" {
  description = "S3 landing bucket name for DMS target output"
  type        = string
}

# KMS
variable "kms_key_arn" {
  description = "KMS key ARN for DMS encryption and Secrets Manager"
  type        = string
  default     = null
}

# DMS Serverless scaling
variable "min_capacity_units" {
  description = "Minimum DMS Serverless capacity units (1 = 1 ACU, min 1 for full-load-and-cdc)"
  type        = number
  default     = 1
}

variable "max_capacity_units" {
  description = "Maximum DMS Serverless capacity units"
  type        = number
  default     = 4
}

variable "multi_az" {
  description = "Enable Multi-AZ for DMS Serverless"
  type        = bool
  default     = false
}

# Task configuration
variable "table_mappings" {
  description = "DMS table mappings JSON (selection rules, transformations)"
  type        = string
  default     = null
}

variable "replication_settings" {
  description = "DMS replication settings JSON (task settings)"
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
