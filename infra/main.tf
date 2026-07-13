module "aurora_postgres" {
  source = "./modules/aurora_postgres"

  project_name = var.project_name
  environment  = var.environment

  vpc_id              = local.effective_vpc_id
  subnet_ids          = local.effective_subnet_ids
  allowed_cidr_blocks = var.aurora_config.allowed_cidr_blocks
  db_name             = var.aurora_config.db_name
  admin_username      = var.rds_admin_username != null ? var.rds_admin_username : var.aurora_config.admin_username
  admin_password      = var.rds_admin_password != null ? var.rds_admin_password : var.aurora_config.admin_password

  snapshot_identifier        = var.rds_snapshot_identifier != null ? var.rds_snapshot_identifier : var.aurora_config.snapshot_identifier
  final_snapshot_identifier  = var.aurora_config.final_snapshot_identifier != null ? var.aurora_config.final_snapshot_identifier : "${var.project_name}-final-snapshot-${formatdate("YYYYMMDDHHMMSS", timestamp())}"
  serverless_min_capacity    = var.aurora_config.serverless_min_capacity
  serverless_max_capacity    = var.aurora_config.serverless_max_capacity
  backup_retention_days      = var.aurora_config.backup_retention_days
  publicly_accessible        = var.aurora_config.publicly_accessible
  skip_final_snapshot        = var.aurora_config.skip_final_snapshot
  deletion_protection        = var.aurora_config.deletion_protection
  log_retention_days         = var.aurora_config.log_retention_days
  create_log_group           = var.aurora_config.create_log_group
  reader_count               = var.aurora_config.reader_count
  auto_minor_version_upgrade = var.aurora_config.auto_minor_version_upgrade

  tags = var.tags
}

module "aws_batch" {
  count  = var.batch_config.enabled ? 1 : 0
  source = "./modules/aws_batch"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  subnet_ids        = local.effective_subnet_ids
  security_group_id = module.aurora_postgres.security_group_id

  ecr_image_uri = var.batch_config.ecr_image_uri

  db_host     = module.aurora_postgres.db_endpoint
  db_port     = module.aurora_postgres.db_port
  db_name     = module.aurora_postgres.db_name
  db_user     = var.rds_admin_username != null ? var.rds_admin_username : var.aurora_config.admin_username
  db_password = var.rds_admin_password != null ? var.rds_admin_password : var.aurora_config.admin_password

  efs_file_system_id  = var.batch_config.efs_file_system_id
  efs_file_system_arn = var.batch_config.efs_file_system_arn

  compute_instance_types      = var.batch_config.compute_instance_types
  compute_min_vcpus           = var.batch_config.compute_min_vcpus
  compute_max_vcpus           = var.batch_config.compute_max_vcpus
  compute_desired_vcpus       = var.batch_config.compute_desired_vcpus
  compute_spot_bid_percentage = var.batch_config.compute_spot_bid_percentage

  job_historical_vcpus  = var.batch_config.job_historical_vcpus
  job_historical_memory = var.batch_config.job_historical_memory
  job_stream_vcpus      = var.batch_config.job_stream_vcpus
  job_stream_memory     = var.batch_config.job_stream_memory
  job_load_ref_vcpus    = var.batch_config.job_load_ref_vcpus
  job_load_ref_memory   = var.batch_config.job_load_ref_memory

  log_retention_days = var.batch_config.log_retention_days

  tags = var.tags

  depends_on = [module.aurora_postgres]
}
