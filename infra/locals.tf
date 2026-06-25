locals {
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
