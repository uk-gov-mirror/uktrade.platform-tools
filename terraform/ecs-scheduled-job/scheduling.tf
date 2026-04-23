### Eventbridge
resource "aws_scheduler_schedule" "this" {

  # Required
  schedule_expression = var.service_config.schedule == "none" ? "rate(5 minutes)" : var.service_config.schedule

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_sfn_state_machine.this.arn
    role_arn = aws_iam_role.eventbridge_scheduler_role.arn
  }

  # Optional
  name       = "${local.full_service_name}-schedule"
  group_name = "default"

  state = var.service_config.schedule == "none" ? "DISABLED" : "ENABLED"

  # retries? 
  #   retry_policy {
  #     maximum_event_age_in_seconds = 60
  #     maximum_retry_attempts = 1
  #   }

}

### State Machine
resource "aws_sfn_state_machine" "this" {
  name     = local.full_service_name
  role_arn = aws_iam_role.state_machine_role.arn

  definition = jsonencode(local.state_machine_definition)
}


