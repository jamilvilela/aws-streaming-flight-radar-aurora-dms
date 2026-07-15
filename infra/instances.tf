# ---------------------------------------------------------------------------
# Aurora Serverless v2 Instance (writer)
# ---------------------------------------------------------------------------
resource "aws_rds_cluster_instance" "writer" {
  identifier                 = "${var.project_name}-aurora-writer"
  cluster_identifier         = aws_rds_cluster.this.id
  instance_class             = "db.serverless"
  engine                     = aws_rds_cluster.this.engine
  engine_version             = aws_rds_cluster.this.engine_version
  auto_minor_version_upgrade = var.aurora_config.auto_minor_version_upgrade
  publicly_accessible        = var.aurora_config.publicly_accessible

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-writer"
  })
}

# ---------------------------------------------------------------------------
# Read replicas (Aurora Reader instances)
# ---------------------------------------------------------------------------
resource "aws_rds_cluster_instance" "reader" {
  count = var.aurora_config.reader_count

  identifier                 = "${var.project_name}-aurora-reader-${count.index + 1}"
  cluster_identifier         = aws_rds_cluster.this.id
  instance_class             = "db.serverless"
  engine                     = aws_rds_cluster.this.engine
  engine_version             = aws_rds_cluster.this.engine_version
  auto_minor_version_upgrade = var.aurora_config.auto_minor_version_upgrade
  publicly_accessible        = false

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-reader-${count.index + 1}"
  })
}
