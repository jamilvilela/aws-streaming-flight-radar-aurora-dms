# ---------------------------------------------------------------------------
# Aurora Serverless v2 PostgreSQL — Cluster Parameter Group
# Configurações essenciais para replicação lógica via pglogical
# ---------------------------------------------------------------------------
resource "aws_rds_cluster_parameter_group" "this" {
  name        = "${var.project_name}-aurora-pg"
  family      = "aurora-postgresql17"
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

  parameter {
    name         = "max_worker_processes"
    value        = "30"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "max_logical_replication_workers"
    value        = "12"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "max_replication_slots"
    value        = "20"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "max_wal_senders"
    value        = "20"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "wal_buffers"
    value        = "65536"
    apply_method = "pending-reboot"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-pg"
  })
}
