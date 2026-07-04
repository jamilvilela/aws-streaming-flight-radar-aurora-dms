variable "project_name" { type = string }
variable "aws_region" { type = string }
variable "environment" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}

# Optional override variables (can be set via .env → TF_VAR_*)
variable "rds_admin_password" {
  description = "Override Aurora admin password (from .env RDS_ADMIN_PASSWORD)"
  type        = string
  default     = null
  sensitive   = true
}

variable "rds_snapshot_identifier" {
  description = "Override Aurora snapshot identifier for restore workflow"
  type        = string
  default     = null
}

variable "buckets" {
  description = "Map of S3 bucket names for different purposes"
  type        = map(string)
}

variable "dms_config" {
  description = "Configuration for AWS DMS Serverless (Aurora PostgreSQL -> S3 Parquet)"
  type = object({
    enabled              = optional(bool, false)
    min_capacity_units   = optional(number, 1)
    max_capacity_units   = optional(number, 4)
    table_mappings       = optional(string)
    replication_settings = optional(string)
  })
  default = {}
}

variable "vpc_name" {
  description = "Name tag of the VPC to use (used when aurora_config.vpc_id is null)"
  type        = string
  default     = null
}

variable "aurora_config" {
  description = "Configuration for the Aurora Serverless v2 PostgreSQL cluster"
  type = object({
    vpc_id                  = optional(string, null)
    subnet_ids              = optional(list(string), null)
    allowed_cidr_blocks     = optional(list(string), ["0.0.0.0/0"])
    db_name                 = optional(string, "flightradar")
    admin_username          = optional(string, "dbadmin")
    admin_password          = string
    serverless_min_capacity = optional(number, 0.5)
    serverless_max_capacity = optional(number, 8)
    backup_retention_days   = optional(number, 7)
    publicly_accessible     = optional(bool, false)
    snapshot_identifier         = optional(string, null)
    final_snapshot_identifier   = optional(string, null)
    skip_final_snapshot         = optional(bool, false)
    deletion_protection         = optional(bool, false)
    log_retention_days      = optional(number, 7)
    reader_count                = optional(number, 0)
    auto_minor_version_upgrade = optional(bool, true)
  })
}
