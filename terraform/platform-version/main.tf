data "aws_caller_identity" "current" {}

resource "aws_ssm_parameter" "platform_version" {
  # checkov:skip=CKV2_AWS_34: This AWS SSM Parameter doesn't need to be encrypted
  name = local.parameter_name
  tier = "Intelligent-Tiering"
  type = "String"
  value = jsonencode({
    "version" : var.platform_version,
    "updated_by" : data.aws_caller_identity.current.user_id,
    "timestamp" : timestamp(),
  })
  tags = local.tags
}
