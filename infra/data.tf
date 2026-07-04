data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# VPC discovery — usado quando aurora_config.vpc_id não é informado
# ---------------------------------------------------------------------------
data "aws_vpc" "selected" {
  count = var.aurora_config.vpc_id != null ? 0 : 1

  tags = {
    Name = var.vpc_name != null ? var.vpc_name : "${var.project_name}-vpc"
  }
}

# ---------------------------------------------------------------------------
# Subnets discovery — usado quando aurora_config.subnet_ids não é informado
# Filtra por VPC (já descoberta ou fornecida) e tags opcionais
# ---------------------------------------------------------------------------
data "aws_subnets" "selected" {
  count = var.aurora_config.subnet_ids != null ? 0 : 1

  filter {
    name   = "vpc-id"
    values = [local.effective_vpc_id]
  }
}
