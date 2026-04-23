locals {
  tags = {
    application = var.application
    environment = var.environment
    service     = var.service_config.name
    managed-by  = "DBT Platform - Service Terraform"
  }

  full_service_name = "${var.application}-${var.environment}-${var.service_config.name}"
  vpc_name          = var.env_config[var.environment]["vpc"]

  retry_max_attempts = lookup(var.service_config, "retries", null) # step function level

  # timeout_seconds = lookup(var.service_config, "timeout", 86400) # TODO: figure out why lookup() breaks the test_state_machine_definition_has_no_timeout test
  timeout_seconds = var.service_config.timeout != null ? var.service_config.timeout : 86400 # set timeout to 24 hours to avoid runaway state machines caused by the default provided by AWS (99999999, which is approximately 3 years). See here: https://docs.aws.amazon.com/step-functions/latest/dg/state-task.html

  ### State Machine
  state_machine_definition = {
    Version        = "1.0"
    Comment        = "Run AWS Fargate task for Scheduled Job ${local.full_service_name}"
    TimeoutSeconds = local.timeout_seconds
    StartAt        = "run-fargate-task"
    States = {
      run-fargate-task = {
        Type     = "Task"
        Resource = "arn:aws:states:::ecs:runTask.sync"
        Parameters = {
          LaunchType      = "FARGATE"
          PlatformVersion = "LATEST"
          Cluster         = data.aws_ecs_cluster.cluster.id
          TaskDefinition  = "" # Replace with aws_ecs_task_definition.service.arn
          PropagateTags   = "TASK_DEFINITION"
          "Group.$"       = "$$.Execution.Name"
          NetworkConfiguration = {
            AwsvpcConfiguration = {
              Subnets = data.aws_subnets.private-subnets.ids
            }
            AssignPublicIp = "DISABLED"
            SecurityGroups = aws_security_group.scheduled_job_sg.id
          }
        }
        Retry = local.retry_max_attempts != null ? [{
          ErrorEquals = [
            "States.ALL"
          ]
          IntervalSeconds = 10 # do we want this value configurable?
          MaxAttempts     = local.retry_max_attempts
          BackoffRate     = 1.5 # do we want this value configurable?
        }] : []

        # notifications state

        End = true
      }
    }

    # include logic for notications here (or space for it!)
  }
}
