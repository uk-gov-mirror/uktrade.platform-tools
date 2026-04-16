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

variables {
  application         = "demodjango"
  environment         = "dev"
  platform_extensions = {} # Empty placeholder to pass validate - declared further down in individual tests

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

    cpu    = 256
    memory = 512
    count  = 1
    exec   = true

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
EventBridge test ideas:
- schedule_expression value assertion (if none or something else)
- state assert ENABLED or DISABLED based on config passed


*/

