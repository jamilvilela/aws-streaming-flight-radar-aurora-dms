# ---------------------------------------------------------------------------
# Security Group — Aurora PostgreSQL
# ---------------------------------------------------------------------------
resource "aws_security_group" "aurora" {
  name        = "${var.project_name}-aurora-sg"
  description = "Security group for ${var.project_name} Aurora Serverless v2"
  vpc_id      = local.effective_vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.aurora_config.allowed_cidr_blocks
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
