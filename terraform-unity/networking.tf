data "local_file" "unity_yaml" {
  filename = "/home/ubuntu/.unity/unity.yaml"
}
locals {
  unity_config = yamldecode(data.local_file.unity_yaml.content)
  project      = local.unity_config.project
  venue        = local.unity_config.venue
}

# Create an Application Load Balancer (ALB)
resource "aws_lb" "httpd_alb" {
  name                       = "${var.deployment_name}-httpd-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.ecs_sg.id]
  subnets                    = local.public_subnet_ids
  enable_deletion_protection = false
  tags = {
    Service = "U-CS"
  }
}

# Create a Target Group for httpd
resource "aws_lb_target_group" "httpd_tg" {
  name        = "${var.deployment_name}-httpd-tg"
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


resource "aws_ssm_parameter" "mgmt_endpoint" {
  name = "/unity/${local.project}/${local.venue}/management/httpd/loadbalancer-url"
  type = "String"
  value = "${aws_lb_listener.httpd_listener.protocol}://${aws_lb.httpd_alb.dns_name}:${aws_lb_listener.httpd_listener.port}/management/ui"
}
