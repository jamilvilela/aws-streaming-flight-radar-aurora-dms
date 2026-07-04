# ---------------------------------------------------------------------------
# Aurora Serverless v2 PostgreSQL — Cluster Parameter Group
# Configurações essenciais para DMS CDC via pglogical
# ---------------------------------------------------------------------------
resource "aws_rds_cluster_parameter_group" "this" {
  name        = "${var.project_name}-aurora-pg"
  family      = "aurora-postgresql16"
  description = "Cluster parameter group for ${var.project_name} Aurora Serverless v2"

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "aurora.enhanced_logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "aurora.logical_replication_backup"
    value        = "0"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "aurora.logical_replication_globaldb"
    value        = "0"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements,pglogical"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "logical_decoding_work_mem"
    value        = "65536"
    apply_method = "pending-reboot"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-pg"
  })
}

# ---------------------------------------------------------------------------
# Subnet group
# ---------------------------------------------------------------------------
resource "aws_db_subnet_group" "this" {
  name        = "${var.project_name}-aurora-subnet-group"
  description = "Subnet group for ${var.project_name} Aurora Serverless v2"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-subnet-group"
  })
}

# ---------------------------------------------------------------------------
# Security group
# ---------------------------------------------------------------------------
resource "aws_security_group" "aurora" {
  name        = "${var.project_name}-aurora-sg"
  description = "Security group for ${var.project_name} Aurora Serverless v2"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "PostgreSQL access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-sg"
  })
}

# ---------------------------------------------------------------------------
# Aurora Serverless v2 Cluster
# ---------------------------------------------------------------------------
resource "aws_rds_cluster" "this" {
  cluster_identifier  = "${var.project_name}-aurora"
  engine              = "aurora-postgresql"
  engine_version      = "17.7"
  engine_mode         = "provisioned"

  database_name       = var.db_name
  master_username     = var.admin_username
  master_password     = var.admin_password
  port                = 5432

  db_subnet_group_name            = aws_db_subnet_group.this.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name
  vpc_security_group_ids          = [aws_security_group.aurora.id]

  storage_encrypted      = true
  kms_key_id            = var.kms_key_arn

  backup_retention_period     = var.backup_retention_days
  preferred_backup_window     = var.backup_window
  preferred_maintenance_window = var.maintenance_window
  snapshot_identifier         = var.snapshot_identifier
  copy_tags_to_snapshot          = true
  final_snapshot_identifier      = var.final_snapshot_identifier
  skip_final_snapshot            = var.skip_final_snapshot
  deletion_protection            = var.deletion_protection

  # Serverless v2 scaling configuration
  serverlessv2_scaling_configuration {
    min_capacity = var.serverless_min_capacity  # 0.5 ACU
    max_capacity = var.serverless_max_capacity  # 8 ACU (max for pg)
  }

  enabled_cloudwatch_logs_exports = ["postgresql"]

  lifecycle {
    ignore_changes = [snapshot_identifier]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora"
  })
}

# ---------------------------------------------------------------------------
# Aurora Serverless v2 Instance (writer)
# ---------------------------------------------------------------------------
resource "aws_rds_cluster_instance" "writer" {
  identifier         = "${var.project_name}-aurora-writer"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  publicly_accessible        = var.publicly_accessible

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-writer"
  })
}

# ---------------------------------------------------------------------------
# Read replicas (Aurora Reader instances)
# ---------------------------------------------------------------------------
resource "aws_rds_cluster_instance" "reader" {
  count = var.reader_count

  identifier         = "${var.project_name}-aurora-reader-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  publicly_accessible        = false

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-reader-${count.index + 1}"
  })
}

# ---------------------------------------------------------------------------
# CloudWatch Log Group — PostgreSQL logs
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "postgres" {
  name              = "/aws/rds/cluster/${var.project_name}-aurora/postgresql"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}
