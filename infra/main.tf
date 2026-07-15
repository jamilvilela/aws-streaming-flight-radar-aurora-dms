# Terraform carrega automaticamente todos os arquivos *.tf do diretório.
# Os recursos estão organizados nos seguintes arquivos:
#
#   locals.tf           — Variáveis locais (VPC, subnets, credenciais)
#   data.tf             — Data sources (VPC, subnets, caller identity)
#   providers.tf        — Provider AWS
#   variables.tf        — Variáveis de entrada
#   outputs.tf          — Outputs
#
#   parameter-group.tf  — Cluster parameter group (pglogical, wal, etc.)
#   subnet-group.tf     — DB subnet group
#   security-group.tf   — Security group (ingress/egress PostgreSQL)
#   main.tf             — Aurora Serverless v2 cluster
#   instances.tf        — Writer + reader instances
#   cloudwatch.tf       — CloudWatch log group
#   tfvars/             — Valores específicos do ambiente

# ---------------------------------------------------------------------------
# Aurora Serverless v2 Cluster
# ---------------------------------------------------------------------------
resource "aws_rds_cluster" "this" {
  cluster_identifier = "${var.project_name}-aurora"
  engine             = "aurora-postgresql"
  engine_version     = "17.7"
  engine_mode        = "provisioned"

  database_name   = var.aurora_config.db_name != null && var.aurora_config.db_name != "" ? var.aurora_config.db_name : null
  master_username = local.effective_admin_username
  master_password = local.effective_admin_password
  port            = 5432

  db_subnet_group_name            = aws_db_subnet_group.this.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name
  vpc_security_group_ids          = [aws_security_group.aurora.id]

  storage_encrypted = true

  backup_retention_period      = var.aurora_config.backup_retention_days
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:05:00-sun:06:00"
  snapshot_identifier          = local.effective_snapshot_id != "" ? local.effective_snapshot_id : null
  copy_tags_to_snapshot        = true
  final_snapshot_identifier    = local.effective_final_snapshot
  skip_final_snapshot          = var.aurora_config.skip_final_snapshot
  deletion_protection          = var.aurora_config.deletion_protection

  # Serverless v2 scaling configuration
  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_config.serverless_min_capacity
    max_capacity = var.aurora_config.serverless_max_capacity
  }

  enabled_cloudwatch_logs_exports = ["postgresql"]

  lifecycle {
    ignore_changes = [snapshot_identifier]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora"
  })
}
