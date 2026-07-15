# ---------------------------------------------------------------------------
# DB Subnet Group
# ---------------------------------------------------------------------------
resource "aws_db_subnet_group" "this" {
  name        = "${var.project_name}-aurora-subnet-group"
  description = "Subnet group for ${var.project_name} Aurora Serverless v2"
  subnet_ids  = local.effective_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-subnet-group"
  })
}
