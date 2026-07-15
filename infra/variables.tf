variable "project_name" { type = string }
variable "aws_region" { type = string }
variable "environment" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}

# Optional override variables (can be set via .env → TF_VAR_*)
variable "rds_admin_username" {
  description = "Override Aurora admin username (from .env DB_USER)"
  type        = string
  default     = null
}

variable "rds_admin_password" {
  description = "Override Aurora admin password (from .env DB_PASSWORD)"
  type        = string
  default     = null
  sensitive   = true
}

variable "rds_snapshot_identifier" {
  description = "Override Aurora snapshot identifier for restore workflow"
  type        = string
  default     = null
}

variable "vpc_name" {
  description = "Name tag of the VPC to use (used when aurora_config.vpc_id is null)"
  type        = string
  default     = null
}

variable "aurora_config" {
  description = "Configuration for the Aurora Serverless v2 PostgreSQL cluster"
  type = object({
    vpc_id                     = optional(string, null)
    subnet_ids                 = optional(list(string), null)
    allowed_cidr_blocks        = optional(list(string), ["0.0.0.0/0"])
    db_name                    = optional(string, "flightradar")
    admin_username             = optional(string, "dbadmin")
    admin_password             = optional(string, "")
    serverless_min_capacity    = optional(number, 0)
    serverless_max_capacity    = optional(number, 4)
    backup_retention_days      = optional(number, 7)
    publicly_accessible        = optional(bool, false)
    snapshot_identifier        = optional(string, null)
    final_snapshot_identifier  = optional(string, null)
    skip_final_snapshot        = optional(bool, false)
    deletion_protection        = optional(bool, false)
    log_retention_days         = optional(number, 7)
    create_log_group           = optional(bool, false)
    reader_count               = optional(number, 0)
    auto_minor_version_upgrade = optional(bool, true)
  })
}


