locals {
  # ── VPC ID: usa o valor explícito ou descobre via data source ──
  effective_vpc_id = var.aurora_config.vpc_id != null ? var.aurora_config.vpc_id : try(data.aws_vpc.selected[0].id, null)

  # ── Subnet IDs: usa a lista explícita ou descobre via data source ──
  effective_subnet_ids = var.aurora_config.subnet_ids != null ? var.aurora_config.subnet_ids : try(data.aws_subnets.selected[0].ids, [])

  # ── Buckets com sufixo do account ID ──
  buckets = merge(
    var.buckets,
    {
      workspace = "${var.buckets.workspace}-${data.aws_caller_identity.current.account_id}"
      landing   = "${var.buckets.landing}-${data.aws_caller_identity.current.account_id}"
      raw       = "${var.buckets.raw}-${data.aws_caller_identity.current.account_id}"
      trusted   = "${var.buckets.trusted}-${data.aws_caller_identity.current.account_id}"
      business  = "${var.buckets.business}-${data.aws_caller_identity.current.account_id}"
    }
  )
}
