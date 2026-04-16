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

resource "aws_ecs_task_definition" "service" {
  family                   = "${local.full_service_name}-task-def"
  requires_compatibilities = ["FARGATE"]
  pid_mode                 = "task"
  region                   = data.aws_region.current.region
  cpu                      = tostring(var.service_config.cpu)
  memory                   = tostring(var.service_config.memory)
  network_mode             = "awsvpc"

  dynamic "ephemeral_storage" {
    for_each = var.service_config.storage.ephemeral != null ? toset([var.service_config.storage.ephemeral]) : toset([20])
    content {
      size_in_gib = ephemeral_storage.ephemeral
    }
  }

  execution_role_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.full_service_name}-task-exec"
  container_definitions = jsonencode(local.container_definitions_list)
  task_role_arn         = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.full_service_name}-ecs-task"

  volume {
    name      = "service-storage"
    host_path = "/ecs/service-storage"
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
  }

  runtime_platform {
    operating_system_family = "WINDOWS_SERVER_2019_CORE"
    cpu_architecture        = "X86_64"
  }
}
