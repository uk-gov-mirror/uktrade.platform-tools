/* 
To include:
- ECS resources (task def, task role, execution role, anything else? reference existing ecs-service module)
- Step Functions resources (can reference this module: https://registry.terraform.io/modules/terraform-aws-modules/step-functions/aws/latest?tab=resources)
- EventBridge Schedule (Schedule, Role and permissions) - add conditional logic that if `schedule: none` then schedule should be disabled
    - default retry policy? adding an SQS queue just for dead letter queue purposes would be a bit scope creep
*/

### Eventbridge
resource "aws_scheduler_schedule" "this" {

  # Required
  schedule_expression = var.service_config.schedule == "none" ? "rate(5 minutes)" : var.service_config.schedule

  flexible_time_window {
    mode = "OFF"
  }

  # to be the State Machine
  target {
    arn      = aws_sfn_state_machine.this.arn
    role_arn = aws_iam_role.example.arn
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
# ...

resource "aws_sfn_state_machine" "this" {
  name     = local.full_service_name
  role_arn = aws_iam_role.state_machine_role.arn

  definition = local.state_machine_definition
}

data "aws_ecs_cluster" "cluster" {
  cluster_name = "${var.application}-${var.environment}-cluster"
}

resource "aws_security_group" "scheduled_job_sg" {
  name        = "security-group-for-scheduled-job"
  description = "SG for scheduled job ECS task"
  vpc_id      = data.aws_vpc.vpc.id

  tags = local.tags
}

resource "aws_vpc_security_group_egress_rule" "scheduled_job_egress" {
  security_group_id = aws_security_group.scheduled_job_sg.id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  tags              = local.tags
}
