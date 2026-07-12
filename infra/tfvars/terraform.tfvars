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

  # Aurora Serverless v2 scaling
  # Aumentado para suportar 5GB de full load + 150MB/5min de streaming CDC
  # min 2 ACU para operação estável com pglogical e WAL pesado
  # max 32 ACU para picos de full load e alto throughput de CDC
  serverless_min_capacity = 2.0
  serverless_max_capacity = 16

  backup_retention_days = 7
  publicly_accessible   = true
  snapshot_identifier   = null
  skip_final_snapshot          = false
  final_snapshot_identifier    = null  # gerado dinamicamente: {project_name}-final-snapshot-{YYYYMMDD}
  deletion_protection          = false
  log_retention_days      = 30
  create_log_group        = false
  reader_count                 = 1  # 1 reader para distribuir carga de leitura durante CDC
  auto_minor_version_upgrade  = true
}

################################################
# DMS Serverless Configuration
# Aumentado para suportar 150MB/5min de throughput CDC:
# - min_capacity_units=2: baseline para CDC contínuo
# - max_capacity_units=32: pico para full load de 5GB
# DMS Serverless escala automaticamente entre min e max baseado na carga.
# O full load de 5GB pode exigir até 32 ACU para conclusão em tempo hábil.
dms_config = {
  enabled            = true
  min_capacity_units = 2
  max_capacity_units = 8
}

