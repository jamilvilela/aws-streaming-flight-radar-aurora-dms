aws_region         = "us-east-1"
project_name       = "flight-radar-stream"
environment        = "production"
vpc_name           = "default-vpc"


buckets = {
  workspace = "lakehouse-workspace"
  raw       = "lakehouse-raw"
  landing   = "lakehouse-landing"
  trusted   = "lakehouse-trusted"
  business  = "lakehouse-business"
}

################################################
tags = {
  Environment = "production"
  Project     = "flight-radar-stream"
  ManagedBy   = "terraform"
}


# =============================================================================
# Aurora Serverless v2 PostgreSQL Configuration
# =============================================================================
# NOTA: Aurora Serverless v2 usa engine_mode="provisioned" com serverlessv2_scaling_configuration.
# O armazenamento é gerenciado automaticamente pelo Aurora (não há allocated_storage).
# A replicação lógica (pglogical) é configurada no cluster parameter group para DMS CDC.
# =============================================================================
# =============================================================================

aurora_config = {
  # vpc_id e subnet_ids agora são descobertos via data.tf
  # vpc_name:  usado para lookup do VPC (default = "${project_name}-vpc")
  allowed_cidr_blocks = ["0.0.0.0/0"]
  db_name             = "flightradar"
  admin_username      = ""
  admin_password      = ""  # override via RDS_ADMIN_PASSWORD in .env

  # Aurora Serverless v2 scaling: 0.5 ACU (min) - 8 ACU (max)
  serverless_min_capacity = 0.5
  serverless_max_capacity = 8

  backup_retention_days = 7
  publicly_accessible   = true
  snapshot_identifier   = null
  skip_final_snapshot          = false
  final_snapshot_identifier    = null  # gerado dinamicamente: {project_name}-final-snapshot-{YYYYMMDD}
  deletion_protection          = false
  reader_count                 = 0  # 0 = apenas writer (mais econômico)
  auto_minor_version_upgrade  = true
}

################################################
# DMS Serverless Configuration
# DMS Serverless gerencia o compute automaticamente — sem necessidade de
# escolher classe de instância ou armazenamento.
# min_capacity_units=1 / max_capacity_units=4 para full-load-and-cdc.
dms_config = {
  enabled            = true
  min_capacity_units = 1
  max_capacity_units = 4
}

