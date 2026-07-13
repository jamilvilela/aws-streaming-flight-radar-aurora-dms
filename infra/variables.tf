variable "project_name" { type = string }
variable "aws_region" { type = string }
variable "environment" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}

# Optional override variables (can be set via .env → TF_VAR_*)
variable "rds_admin_username" {
  description = "Override Aurora admin username (from .env RDS_ADMIN_USERNAME)"
  type        = string
  default     = null
}

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
    serverless_min_capacity    = optional(number, 2.0)
    serverless_max_capacity    = optional(number, 32)
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

variable "batch_config" {
  description = "Configuration for AWS Batch compute environment and job definitions"
  type = object({
    enabled                     = optional(bool, false)
    ecr_image_uri               = optional(string, "")
    efs_file_system_id          = optional(string, "")
    efs_file_system_arn         = optional(string, "")
    compute_instance_types      = optional(list(string), ["t3.medium", "t3.large"])
    compute_min_vcpus           = optional(number, 0)
    compute_max_vcpus           = optional(number, 16)
    compute_desired_vcpus       = optional(number, 0)
    compute_spot_bid_percentage = optional(number, 100)

    job_historical_vcpus  = optional(number, 2)
    job_historical_memory = optional(number, 4096)
    job_stream_vcpus      = optional(number, 1)
    job_stream_memory     = optional(number, 2048)
    job_load_ref_vcpus    = optional(number, 1)
    job_load_ref_memory   = optional(number, 1024)

    log_retention_days = optional(number, 30)
  })
  default = {}
}
