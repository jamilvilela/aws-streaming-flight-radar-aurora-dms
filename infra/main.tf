module "aurora_postgres" {
  source = "./modules/aurora_postgres"

  project_name = var.project_name
  environment  = var.environment

  vpc_id              = var.aurora_config.vpc_id
  subnet_ids          = var.aurora_config.subnet_ids
  allowed_cidr_blocks = var.aurora_config.allowed_cidr_blocks
  db_name             = var.aurora_config.db_name
  admin_username      = var.aurora_config.admin_username
  admin_password      = var.rds_admin_password != null ? var.rds_admin_password : var.aurora_config.admin_password

  snapshot_identifier         = var.rds_snapshot_identifier != null ? var.rds_snapshot_identifier : var.aurora_config.snapshot_identifier
  final_snapshot_identifier   = var.aurora_config.final_snapshot_identifier != null ? var.aurora_config.final_snapshot_identifier : "${var.project_name}-final-snapshot-${formatdate("YYYYMMDD", timestamp())}"
  serverless_min_capacity     = var.aurora_config.serverless_min_capacity
  serverless_max_capacity     = var.aurora_config.serverless_max_capacity
  backup_retention_days       = var.aurora_config.backup_retention_days
  publicly_accessible         = var.aurora_config.publicly_accessible
  skip_final_snapshot         = var.aurora_config.skip_final_snapshot
  deletion_protection         = var.aurora_config.deletion_protection
  log_retention_days       = var.aurora_config.log_retention_days
  reader_count             = var.aurora_config.reader_count
  auto_minor_version_upgrade = var.aurora_config.auto_minor_version_upgrade

  tags = var.tags
}

module "dms_serverless" {
  count  = var.dms_config.enabled ? 1 : 0
  source = "./modules/dms_serverless"

  project_name = var.project_name
  environment  = var.environment
  region       = var.aws_region

  vpc_id                  = var.aurora_config.vpc_id
  subnet_ids              = var.aurora_config.subnet_ids
  aurora_security_group_id = module.aurora_postgres.security_group_id

  aurora_endpoint = module.aurora_postgres.db_endpoint
  aurora_port     = module.aurora_postgres.db_port
  aurora_db_name  = module.aurora_postgres.db_name

  landing_bucket_name    = local.buckets.landing
  min_capacity_units     = var.dms_config.min_capacity_units
  max_capacity_units     = var.dms_config.max_capacity_units
  replication_settings   = var.dms_config.replication_settings
  table_mappings         = var.dms_config.table_mappings != null ? var.dms_config.table_mappings : jsonencode({
    rules = [
      {
        "rule-type"     = "selection"
        "rule-id"       = "1"
        "rule-name"     = "flight_radar_aircraft"
        "object-locator" = {
          "schema-name" = "flight_radar"
          "table-name"  = "aircraft"
        }
        "rule-action"   = "include"
      },
      {
        "rule-type"     = "selection"
        "rule-id"       = "2"
        "rule-name"     = "flight_radar_airports"
        "object-locator" = {
          "schema-name" = "flight_radar"
          "table-name"  = "airports"
        }
        "rule-action"   = "include"
      },
      {
        "rule-type"     = "selection"
        "rule-id"       = "3"
        "rule-name"     = "flight_radar_airlines"
        "object-locator" = {
          "schema-name" = "flight_radar"
          "table-name"  = "airlines"
        }
        "rule-action"   = "include"
      },
      {
        "rule-type"     = "selection"
        "rule-id"       = "4"
        "rule-name"     = "flight_radar_flights"
        "object-locator" = {
          "schema-name" = "flight_radar"
          "table-name"  = "flights"
        }
        "rule-action"   = "include"
      },
      {
        "rule-type"     = "selection"
        "rule-id"       = "5"
        "rule-name"     = "flight_radar_positions"
        "object-locator" = {
          "schema-name" = "flight_radar"
          "table-name"  = "aircraft_positions"
        }
        "rule-action"   = "include"
      },
      {
        "rule-type"     = "selection"
        "rule-id"       = "6"
        "rule-name"     = "exclude_dms_control"
        "object-locator" = {
          "schema-name" = "dms_control"
          "table-name"  = "%"
        }
        "rule-action"   = "exclude"
      }
    ]
  })

  log_retention_days = 7
  tags               = var.tags

  depends_on = [
    module.aurora_postgres
  ]
}
