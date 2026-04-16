locals {
  tags = {
    application = var.application
    environment = var.environment
    service     = var.service_config.name
    managed-by  = "DBT Platform - Service Terraform"
  }

  full_service_name = "${var.application}-${var.environment}-${var.service_config.name}"
  vpc_name          = var.env_config[var.environment]["vpc"]
  secrets           = values(coalesce(var.service_config.secrets, {}))

  ecs_service_connect_required = (try(var.service_config.image.port, null) != null) ? 1 : 0
  # REMOVE
  # target_container             = try(var.service_config.http.target_container, "")

  central_log_group_arns        = jsondecode(data.aws_ssm_parameter.log-destination-arn.value)
  central_log_group_destination = var.environment == "prod" ? local.central_log_group_arns["prod"] : local.central_log_group_arns["dev"]

  # retries is an optional number (max attempts). Defaults to 1; set to 0 to disable the Retry block.   
  retry_max_attempts = coalesce(var.service_config.retries, null) # step function level

  # CPU architecture — defaults to X86_64; set platform = "arm64" for Graviton.                         
  cpu_architecture = try(lower(var.service_config.platform), null) == "arm64" ? "ARM64" : "X86_64"



  ##############################
  # S3 EXTENSIONS — SAME ACCOUNT
  ##############################

  # 1) Select S3 extensions
  s3_extensions_all = {
    for name, ext in try(var.platform_extensions, {}) :
    name => ext
    if try(ext.type, "") == "s3" || try(ext.type, "") == "s3-policy"
  }

  # 2) Keep only S3 extensions that apply to this service
  s3_extensions_for_service = {
    for name, ext in local.s3_extensions_all :
    name => ext
    if contains(try(ext.services, []), "__all__") || contains(try(ext.services, []), var.service_config.name)
  }

  # 3) Merge "*" defaults with env-specific overrides
  s3_extensions_for_service_with_env_merged = {
    for name, ext in local.s3_extensions_for_service :
    name => merge(
      lookup(try(ext.environments, {}), "*", {}),
      lookup(try(ext.environments, {}), var.environment, {})
    )
  }

  # 4) Check if buckets are static
  is_s3_static = {
    for name, ext in local.s3_extensions_for_service :
    name => try(ext.serve_static_content, false)
  }

  # 5) Resolve s3 bucket names for static and NON-static buckets
  s3_bucket_name = {
    for name, ext in local.s3_extensions_for_service_with_env_merged :
    name => (
      local.is_s3_static[name]
      ? (var.environment == "prod" ? "${ext.bucket_name}.${var.application}.prod.uktrade.digital" : "${ext.bucket_name}.${var.environment}.${var.application}.uktrade.digital")
      : ext.bucket_name
    )
  }

  # 6) KMS alias only for NON-static buckets
  s3_kms_alias_for_s3_extension = {
    for name, ext in local.s3_extensions_for_service_with_env_merged :
    name => "alias/${var.application}-${var.environment}-${ext.bucket_name}-key"
    if !local.is_s3_static[name]
  }


  ###########################
  # S3 EXTENSIONS — CROSS-ENV
  ###########################

  # 1) Collect all S3 cross environment rules across all S3 extensions
  s3_cross_env_rules_list = flatten([
    for ext_name, ext in try(var.platform_extensions, {}) : [
      for bucket_env, envconf in try(ext.environments, {}) : [
        for access_name, access in try(envconf.cross_environment_service_access, {}) : {
          key         = "${ext_name}:${bucket_env}:${access_name}"
          type        = try(ext.type, null)
          service     = try(access.service, null)
          service_env = try(access.environment, null) # env of the service that wants S3 access
          bucket_env  = bucket_env                    # env that owns the S3 bucket
          is_static   = try(ext.serve_static_content, false)
          bucket_name = (try(ext.serve_static_content, false)
            ? (bucket_env == "prod"
              ? "${envconf.bucket_name}.${var.application}.prod.uktrade.digital"
            : "${envconf.bucket_name}.${bucket_env}.${var.application}.uktrade.digital")
            : envconf.bucket_name
          )
          bucket_account = try(var.env_config[bucket_env].accounts.deploy.id, null)
          read           = try(access.read, false)
          write          = try(access.write, false)
        }
      ]
    ]
  ])

  # 2) Validate cross env config, and filter out rules that don't apply to this service
  s3_cross_env_rules_for_this_service = {
    for rule in local.s3_cross_env_rules_list :
    rule.key => rule
    if(rule.type == "s3" || rule.type == "s3-policy")
    && rule.service == var.service_config.name
    && rule.service_env == var.environment
    && rule.bucket_name != null
    && rule.bucket_account != null
  }


  ##########################################################
  # CONTAINER DEFINITIONS TEMPLATE (USED IN PLATFORM HELPER)
  ##########################################################

  # TODO - Remove COPILOT_ vars once nopilot is complete. Check ALL codebases for any references to them before removal.
  required_env_vars = {
    COPILOT_APPLICATION_NAME            = var.application
    COPILOT_ENVIRONMENT_NAME            = var.environment
    COPILOT_SERVICE_NAME                = var.service_config.name
    COPILOT_SERVICE_DISCOVERY_ENDPOINT  = "${var.environment}.${var.application}.local"
    PLATFORM_APPLICATION_NAME           = var.application
    PLATFORM_ENVIRONMENT_NAME           = var.environment
    PLATFORM_SERVICE_NAME               = var.service_config.name
    PLATFORM_SERVICE_DISCOVERY_ENDPOINT = "${var.environment}.${var.application}.services.local"
  }

  default_container_config = {
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/platform/ecs/scheduled-job/${var.application}/${var.environment}/${var.service_config.name}"
        awslogs-region        = data.aws_region.current.region
        awslogs-stream-prefix = "platform"
      }
    }
  }

  depends_on_map = {
    for k, v in coalesce(try(var.service_config.image.depends_on, {}), {}) :
    k => upper(v)
  }

  writable_directories = coalesce(try(var.service_config.storage.writable_directories, null), [])

  main_container = merge(
    local.default_container_config,
    {
      name      = var.service_config.name
      image     = var.service_config.image.location
      essential = var.service_config.essential
      environment = [
        for k, v in merge(try(var.service_config.variables, {}), local.required_env_vars) :
        { name = k, value = tostring(v) }
      ]
      secrets = [
        for k, v in coalesce(var.service_config.secrets, {}) :
        { name = k, valueFrom = v }
      ]
      readonlyRootFilesystem = var.service_config.storage.readonly_fs
      mountPoints = concat([
        { sourceVolume = "path-tmp", containerPath = "/tmp" }
        ], [
        for path in local.writable_directories : {
          sourceVolume  = "path${replace(path, "/", "-")}"
          containerPath = path
        }
      ])

      # Ensure main container always starts last
      dependsOn = concat([
        for sidecar in keys(coalesce(var.service_config.sidecars, {})) : {
          containerName = sidecar
          condition     = lookup(local.depends_on_map, sidecar, "START")
        }
        ], [
        {
          containerName = "writable_directories_permission"
          condition     = "SUCCESS"
        }
        ]
      )
    },
    try(var.service_config.entrypoint, null) != null ?
    { entryPoint = var.service_config.entrypoint } : {},

    try(var.service_config.image.healthcheck, null) != null ?
    {
      healthCheck = {
        command     = var.service_config.image.healthcheck.command
        interval    = var.service_config.image.healthcheck.interval
        retries     = var.service_config.image.healthcheck.retries
        timeout     = var.service_config.image.healthcheck.timeout
        startPeriod = var.service_config.image.healthcheck.start_period
      }
    } : {},

    try(var.service_config.image.port, null) != null ? { portMappings = [{ containerPort = var.service_config.image.port, protocol = "tcp" }] } : {},
  )

  # Intialises /tmp as writable before the main container starts
  permissions_container = merge(local.default_container_config, {
    name      = "writable_directories_permission"
    image     = "public.ecr.aws/docker/library/alpine:latest"
    essential = false
    command = [
      "/bin/sh",
      "-c",
      "chmod -R a+w /tmp ${length(local.writable_directories) > 0 ? "&& chown -R 1002:1000 ${join(" ", local.writable_directories)}" : ""}"
    ]
    mountPoints = concat([
      { sourceVolume = "path-tmp", readOnly = false, containerPath = "/tmp" }
      ], [
      for path in local.writable_directories :
      { sourceVolume = "path${replace(path, "/", "-")}", readOnly = false, containerPath = path }
    ])
  })


  sidecar_containers = [
    for sidecar_name, sidecar in coalesce(var.service_config.sidecars, {}) : merge(
      local.default_container_config,
      {
        name      = sidecar_name
        image     = sidecar.image
        essential = sidecar.essential
        environment = [
          for k, v in merge(coalesce(sidecar.variables, {}), local.required_env_vars) :
          { name = k, value = tostring(v) }
        ]
        secrets = [
          for k, v in coalesce(sidecar.secrets, {}) : { name = k, valueFrom = v }
        ]

        portMappings = sidecar.port != null ? [
          { containerPort = sidecar.port, protocol = "tcp" }
        ] : []

      },
      try(sidecar.healthcheck, null) != null ?
      {
        healthCheck = {
          command     = sidecar.healthcheck.command
          interval    = sidecar.healthcheck.interval
          retries     = sidecar.healthcheck.retries
          timeout     = sidecar.healthcheck.timeout
          startPeriod = sidecar.healthcheck.start_period
        }
      } : {},
    )
  ]

  container_definitions_list = concat(
    [local.main_container],
    local.sidecar_containers,
    [local.permissions_container]
  )

  writable_volumes = [
    for path in local.writable_directories :
    { name = "path${replace(path, "/", "-")}", host = {} }
  ]

  task_definition_json = jsonencode(
    merge(
      {
        family                  = "${local.full_service_name}-task-def"
        taskRoleArn             = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${full_service_name}-ecs-task"
        executionRoleArn        = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${full_service_name}-task-exec"
        networkMode             = "awsvpc"
        containerDefinitions    = local.container_definitions_list
        volumes                 = concat([{ "name" : "path-tmp", "host" : {} }], local.writable_volumes)
        placementConstraints    = []
        requiresCompatibilities = ["FARGATE"]
        cpu                     = tostring(var.service_config.cpu)
        memory                  = tostring(var.service_config.memory)
        pidMode                 = "task"
        cpuArchitecture         = local.cpu_architecture
        tags = [
          { "key" : "application", "value" : var.application },
          { "key" : "environment", "value" : var.environment },
          { "key" : "service", "value" : var.service_config.name },
          { "key" : "managed-by", "value" : "DBT Platform" },
        ]
      },
      var.service_config.storage.ephemeral != null ? {
        ephemeralStorage = {
          sizeInGiB = var.service_config.storage.ephemeral
        }
      } : {}
    )
  )

  ### State Machine
  state_machine_definition = jsonencode(
    {
      Version = "1.0"
      Comment = "Run AWS Fargate task for Scheduled Job ${local.full_service_name}"
      StartAt = "run-fargate-task"
      States = {
        run-fargate-task = {
          Type     = "Task"
          Resource = "arn:aws:states:::ecs:runTask.sync"
          Parameters = {
            LaunchType      = "FARGATE"
            PlatformVersion = "LATEST"
            Cluster         = data.aws_ecs_cluster.cluster.id
            TaskDefinition  = aws_ecs_task_definition.scheduled_job.arn
            PropagateTags   = "TASK_DEFINITION"
            "Group.$"       = "$$.Execution.Name"
            NetworkConfiguration = {
              AwsvpcConfiguration = {
                Subnets = data.aws_subnets.private-subnets.ids
              }
              AssignPublicIp = "DISABLED"
              SecurityGroups = "something" # TODO create a dedicated security group for Scheduled Jobs
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
  )
}
