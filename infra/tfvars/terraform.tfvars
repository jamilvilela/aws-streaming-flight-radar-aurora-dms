aws_region   = "us-east-1"
project_name = "flight-radar-stream"
environment  = "production"
vpc_name     = "default-vpc"


tags = {
  Environment = "production"
  Project     = "flight-radar-stream"
  ManagedBy   = "terraform"
}


# =============================================================================
# Aurora Serverless v2 PostgreSQL Configuration
# =============================================================================
# NOTA: Aurora Serverless v2 usa engine_mode="provisioned" com
# serverlessv2_scaling_configuration. O armazenamento é gerenciado
# automaticamente pelo Aurora (não há allocated_storage).
# A replicação lógica (pglogical) é configurada no cluster parameter group.
# =============================================================================

aurora_config = {
  allowed_cidr_blocks = ["0.0.0.0/0"]
  db_name             = null   # null para casar com o snapshot (DatabaseName: None)
  admin_username      = ""
  admin_password      = "" # override via RDS_ADMIN_PASSWORD in .env

  serverless_min_capacity = 0.0
  serverless_max_capacity = 4

  backup_retention_days      = 7
  publicly_accessible        = true
  snapshot_identifier        = "flight-radar-stream-final-snapshot-20260713"
  skip_final_snapshot        = false
  final_snapshot_identifier  = null
  deletion_protection        = false
  log_retention_days         = 30
  create_log_group           = false
  reader_count               = 0
  auto_minor_version_upgrade = true
}

################################################
# AWS Batch Configuration
################################################
batch_config = {
  enabled = false
  ecr_image_uri = ""
  efs_file_system_id  = ""
  efs_file_system_arn = ""

  compute_instance_types      = ["m6i.large", "c6a.large", "m5.large"]
  compute_min_vcpus           = 0
  compute_max_vcpus           = 16
  compute_desired_vcpus       = 0
  compute_spot_bid_percentage = 100

  job_historical_vcpus  = 2
  job_historical_memory = 4096
  job_stream_vcpus      = 1
  job_stream_memory     = 2048
  job_load_ref_vcpus    = 1
  job_load_ref_memory   = 1024

  log_retention_days = 30
}

