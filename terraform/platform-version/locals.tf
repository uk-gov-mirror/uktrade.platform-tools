locals {
  tags = merge(
    {
      application = var.application
      managed-by  = "DBT Platform - Terraform"
    },
    var.environment != null ? {
      environment = var.environment
    } : {},
    var.service_name != null ? {
      service = var.service_name
    } : {},
    var.pipeline_type == "codebase-pipeline" ? {
      pipeline = "codebase-pipeline"
    } : {},
    var.pipeline_type == "environment-pipeline" ? {
      pipeline = "environment-pipeline"
    } : {}
  )

  parameter_name_parts = compact([
    "/platform/version/application",
    var.application,
    var.environment != null ? "environment" : null,
    var.environment,
    var.service_name != null ? "service" : null,
    var.service_name,
    var.pipeline_type == "codebase-pipeline" ? "codebase-pipeline" : null,
    var.pipeline_type == "environment-pipeline" ? "environment-pipeline" : null,
  ])

  parameter_name = join("/", local.parameter_name_parts)
}
