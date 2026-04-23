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
