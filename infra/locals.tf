locals {
  # ── VPC ID: usa o valor explícito ou descobre via data source ──
  effective_vpc_id = var.aurora_config.vpc_id != null ? var.aurora_config.vpc_id : try(data.aws_vpc.selected[0].id, null)

  # ── Subnet IDs: usa a lista explícita ou descobre via data source ──
  effective_subnet_ids = var.aurora_config.subnet_ids != null ? var.aurora_config.subnet_ids : try(data.aws_subnets.selected[0].ids, [])
}
