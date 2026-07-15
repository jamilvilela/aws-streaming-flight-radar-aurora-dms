# ---------------------------------------------------------------------------
# CloudWatch Log Group — PostgreSQL logs
# O RDS cria automaticamente este log group ao habilitar cloudwatch_logs_exports.
# Usamos data source para referenciar o existente, evitando erro "already exists".
# O resource opcional só cria se não existir (ex: primeira execução sem RDS).
# ---------------------------------------------------------------------------
data "aws_cloudwatch_log_group" "postgres" {
  name = "/aws/rds/cluster/${var.project_name}-aurora/postgresql"
}

resource "aws_cloudwatch_log_group" "postgres" {
  count             = var.aurora_config.create_log_group ? 1 : 0
  name              = "/aws/rds/cluster/${var.project_name}-aurora/postgresql"
  retention_in_days = var.aurora_config.log_retention_days
  tags              = var.tags
}
