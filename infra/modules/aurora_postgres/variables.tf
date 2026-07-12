variable "project_name" {
  description = "Project name used as resource prefix"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for Aurora security group"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for Aurora (minimum 2 in different AZs)"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to PostgreSQL"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "flightradar"
}

variable "admin_username" {
  description = "Admin username for PostgreSQL"
  type        = string
  default     = "dbadmin"
}

variable "admin_password" {
  description = "Admin password for PostgreSQL"
  type        = string
  sensitive   = true
}

variable "kms_key_arn" {
  description = "KMS key ARN for storage encryption (null = AWS managed)"
  type        = string
  default     = null
}

variable "serverless_min_capacity" {
  description = "Minimum Aurora Serverless v2 capacity units (ACU). 0.5 is the minimum."
  type        = number
  default     = 0.5
}

variable "serverless_max_capacity" {
  description = "Maximum Aurora Serverless v2 capacity units (ACU). Max 128 for Aurora PostgreSQL."
  type        = number
  default     = 8
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Daily backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window (UTC)"
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "final_snapshot_identifier" {
  description = "Identifier for the final snapshot when skip_final_snapshot = false"
  type        = string
  default     = null
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying (set false for prod)"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "Make Aurora instances publicly accessible"
  type        = bool
  default     = false
}

variable "auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades during maintenance windows"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "create_log_group" {
  description = "Create CloudWatch log group (set false if RDS creates it automatically)"
  type        = bool
  default     = false
}

variable "reader_count" {
  description = "Number of Aurora reader instances (0 = writer only)"
  type        = number
  default     = 0
}

variable "snapshot_identifier" {
  description = "Cluster snapshot to restore from (null = create fresh). Set during restore workflow."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
