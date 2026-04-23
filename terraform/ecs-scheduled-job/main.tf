### ECS
data "aws_ecs_cluster" "cluster" {
  cluster_name = "${var.application}-${var.environment}-cluster"
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
    for_each = var.service_config.storage.ephemeral != null ? toset([var.service_config.storage.ephemeral]) : toset([])
    content {
      size_in_gib = ephemeral_storage.value
    }
  }

  execution_role_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.full_service_name}-task-exec"
  container_definitions = jsonencode(local.container_definitions_list)
  task_role_arn         = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.full_service_name}-ecs-task"

  dynamic "volume" {
    for_each = local.volumes
    content {
      name      = volume.value["name"]
      host_path = volume.value["host"]
    }
  }

  runtime_platform {
    cpu_architecture = local.cpu_architecture
  }

  tags = local.tags
}
