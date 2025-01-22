# Create an Application Load Balancer (ALB)
resource "aws_lb" "httpd_alb" {
  name                       = "${var.project}-${var.venue}-httpd-alb"
  internal                   = true
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.ecs_alb_sg.id]
  subnets                    = local.subnet_ids
  enable_deletion_protection = false
  preserve_host_header       = true
  tags = {
    Service = "U-CS"
  }
}

# Create a Target Group for httpd
resource "aws_lb_target_group" "httpd_tg" {
  name        = "${var.project}-${var.venue}-httpd-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value
  target_type = "ip"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
  }
  tags = {
    Service = "U-CS"
  }
}

# Create a Listener for the ALB that forwards requests to the httpd Target Group
#tfsec:ignore:avd-aws-0054
resource "aws_lb_listener" "httpd_listener" {
  load_balancer_arn = aws_lb.httpd_alb.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.httpd_tg.arn
  }
  tags = {
    Service = "U-CS"
  }
}
# Unity shared serive account ID
data "aws_ssm_parameter" "shared_service_account_id" {
  name = var.ssm_account_id
}

#Unity shared serive account region
data "aws_ssm_parameter" "shared_service_region" {
  name = var.ssm_region
}

# Unity CS Common Lambda Authorizer Allowed Cognito User Pool ID
data "aws_ssm_parameter" "shared-service-domain" {
  name = "arn:aws:ssm:${data.aws_ssm_parameter.shared_service_region.value}:${data.aws_ssm_parameter.shared_service_account_id.value}:parameter/unity/shared-services/domain"
}


resource "aws_ssm_parameter" "mgmt_endpoint" {
  name  = "/unity/${var.project}/${var.venue}/management/httpd/loadbalancer-url"
  type  = "String"
  value = "${aws_lb_listener.httpd_listener.protocol}://${aws_lb.httpd_alb.dns_name}:${aws_lb_listener.httpd_listener.port}/${var.project}/${var.venue}/management/ui"
}

# New SSM parameter for management console
resource "aws_ssm_parameter" "management_console_url" {
  name = "/unity/${var.project}/${var.venue}/component/management-console"
  type = "String"
  value = jsonencode({
    healthCheckUrl = "https://www.${data.aws_ssm_parameter.shared-service-domain.value}:4443/${var.project}/${var.venue}/management/api/health_checks"
    landingPageUrl = "https://www.${data.aws_ssm_parameter.shared-service-domain.value}:4443/${var.project}/${var.venue}/management/ui/landing"
    componentName  = "Management Console"
  })
}

# Find the MC's ALB's security group (created before unity-proxy)
data "aws_security_group" "mc_alb_sg" {
  tags = {
    Name        = "Unity ${var.project}-${var.venue} Management Console LB SG"
    Venue       = var.venue
    ServiceArea = "cs"
    Proj        = var.project
  }
}

# Add a new ingress rule to the MC ALB's security group, allowing the ECS instance to connect
resource "aws_vpc_security_group_ingress_rule" "ecs_mc_alb_ingress_sg_rule" {
  security_group_id            = data.aws_security_group.mc_alb_sg.id
  to_port                      = 8080
  from_port                    = 8080
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_sg.id
}

# Add a new ingress rule to the ECS's security group, allowing the ECS instance to connect
resource "aws_vpc_security_group_ingress_rule" "ecs_alb_ingress_sg_rule" {
  security_group_id            = aws_security_group.ecs_sg.id
  to_port                      = 8080
  from_port                    = 8080
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs_alb_sg.id
}

# Add a new egress rule to the ECS's security group, allowing ECS to fetch the container images/proxy
resource "aws_vpc_security_group_egress_rule" "ecs_egress_sg_rule" {
  security_group_id = aws_security_group.ecs_sg.id
  to_port           = 65535
  from_port         = 0
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# Add a new egress rule to the ECS's security group, allowing the ALB to respond to requests
resource "aws_vpc_security_group_egress_rule" "ecs_alb_egress_sg_rule" {
  security_group_id = aws_security_group.ecs_alb_sg.id
  to_port           = 65535
  from_port         = 0
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

data "aws_ssm_parameter" "shared-services_security_group" {
  name = "arn:aws:ssm:${data.aws_ssm_parameter.shared_service_region.value}:${data.aws_ssm_parameter.shared_service_account_id.value}:parameter/unity/shared-services/network/httpd_security_group"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_alb_sg_ingress_rule" {
  security_group_id = aws_security_group.ecs_alb_sg.id
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
  referenced_security_group_id = data.aws_ssm_parameter.shared-services_security_group.id
}

resource "aws_vpc_security_group_egress_rule" "ecs_sg_egress_rule" {
  security_group_id            = aws_security_group.ecs_sg.id
  from_port                    = 0
  to_port                      = 65535
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.aws_security_group.mc_alb_sg.id
}
