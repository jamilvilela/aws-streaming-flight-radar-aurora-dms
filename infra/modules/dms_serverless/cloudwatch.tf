# ---------------------------------------------------------------------------
# CloudWatch log group for DMS Serverless
# DMS Serverless cria logs em dms-replication-config-<config-id> automaticamente
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "dms" {
  name              = "dms-replication-config-${var.project_name}-dms-serverless-config"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-dms-serverless-log-group"
  })
}
