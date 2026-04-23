# Also in ecs-service main.tf, but with 'count = local.web_service_required' 
data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = [local.vpc_name]
  }
}