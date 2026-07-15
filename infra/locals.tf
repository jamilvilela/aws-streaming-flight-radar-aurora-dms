locals {
  # ── VPC ID: usa o valor explícito ou descobre via data source ──
  effective_vpc_id = var.aurora_config.vpc_id != null ? var.aurora_config.vpc_id : try(data.aws_vpc.selected[0].id, null)

  # ── Subnet IDs: usa a lista explícita ou descobre via data source ──
  effective_subnet_ids = var.aurora_config.subnet_ids != null ? var.aurora_config.subnet_ids : try(data.aws_subnets.selected[0].ids, [])

  # ── Credenciais e snapshot (com override via .env + TF_VAR_) ──
  effective_admin_username = var.rds_admin_username != null ? var.rds_admin_username : var.aurora_config.admin_username
  effective_admin_password = var.rds_admin_password != null ? var.rds_admin_password : var.aurora_config.admin_password
  effective_snapshot_id    = var.rds_snapshot_identifier != null ? var.rds_snapshot_identifier : var.aurora_config.snapshot_identifier
  effective_final_snapshot = var.aurora_config.final_snapshot_identifier != null ? var.aurora_config.final_snapshot_identifier : "${var.project_name}-final-snapshot-${formatdate("YYYYMMDDHHMM", timestamp())}"
}
