mock_provider "aws" {}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "001122334455"
  }
}

override_data {
  target = data.aws_region.current
  values = {
    name = "eu-west-2"
  }
}

override_data {
  target = data.aws_vpc.vpc
  values = {
    id         = "vpc-00112233aabbccdef"
    cidr_block = "10.0.0.0/16"
  }
}

override_data {
  target = data.aws_iam_policy_document.assume_role
  values = {
    json = "{\"Sid\": \"PlaceholderPolicyDoesNotMatter\"}"
  }
}

override_data {
  target = data.aws_iam_policy_document.execute_command
  values = {
    json = "{\"Sid\": \"PlaceholderPolicyDoesNotMatter\"}"
  }
}

override_data {
  target = data.aws_iam_policy_document.appconfig
  values = {
    json = "{\"Sid\": \"PlaceholderPolicyDoesNotMatter\"}"
  }
}

override_data {
  target = data.aws_iam_policy_document.service_logs
  values = {
    json = "{\"Sid\": \"PlaceholderPolicyDoesNotMatter\"}"
  }
}

override_data {
  target = data.aws_ssm_parameter.log-destination-arn
  values = {
    value = "{\"dev\":\"arn:aws:logs:eu-west-2:001122334455:log-group:/central/dev\",\"prod\":\"arn:aws:logs:eu-west-2:001122334455:log-group:/central/prod\"}"
  }
}


variables {
  application         = "demodjango"
  environment         = "dev"
  platform_extensions = {} # Empty placeholder to pass validate - declared further down in individual tests

  name = "db-dump"

  env_config = {
    dev = {
      accounts = {
        deploy = { name = "sandbox", id = "000123456789" }
        dns    = { name = "dev", id = "123456" }
      }
      vpc                     = "test-vpc"
      service-deployment-mode = "doesn't matter"
    }
    hotfix = {
      accounts = {
        deploy = { name = "prod", id = "999888777666" }
        dns    = { name = "dev", id = "123456" }
      }
      vpc = "test-vpc-hotfix"
    }
  }

  service_config = {
    name = "web"
    type = "Scheduled Job"

    image = {
      location = "public.ecr.aws/example/app:latest"
      port     = 8080
    }

    cpu       = 256
    memory    = 512
    count     = 1
    exec      = true
    essential = true

    schedule = "none"

    storage = {
      readonly_fs          = false
      writable_directories = []
    }

    # sidecars = {
    #   nginx = {
    #     port  = 443
    #     image = "public.ecr.aws/example/nginx:latest"
    #   }
    # }

    # network = {
    #   connect = true
    #   vpc = {
    #     placement = "private"
    #   }
    # }


    #   variables = {
    #     LOG_LEVEL = "DEBUG"
    #     DEBUG     = false
    #     PORT      = 8080
    #   }

    #   secrets = {
    #     DJANGO_SECRET_KEY = "/copilot/demodjango/dev/secrets/DJANGO_SECRET_KEY"
    #   }
  }

}

/* 
ECS tests:
- platform (cpu architecture)
- ephemeral storage
- volumes

More generally - how do we handle testing shared functionality in both ecs-service and ecs-scheduled-job?
- Duplicating all tests that are relevant from ecs-service to ecs-scheduled-job?
- Splitting out shared module functionality into a 3rd module, and then having ecs-service and ecs-scheduled-job call the 3rd module? The 3rd module owns all the shared tests 
 */

run "test_ecs_task_default_platform_is_x86_64" {
  command = plan

  assert {
    condition     = local.cpu_architecture == "X86_64"
    error_message = "Should be 'X86_64'"
  }
}

run "test_ecs_task_platform_is_arm64" {
  command = plan

  variables {
    service_config = merge(var.service_config, { platform = "arm64" })
  }

  assert {
    condition     = local.cpu_architecture == "ARM64"
    error_message = "Should be 'ARM64'"
  }
}