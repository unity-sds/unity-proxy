provider "aws" {
  region = "us-west-2"
}

variable "tags" {
  description = "AWS Tags"
  type = map(string)
}

variable "deployment_name" {
  description = "The deployment name"
  type        = string
}

data "aws_ssm_parameter" "vpc_id" {
  name = "/unity/account/network/vpc_id"
}

data "aws_ssm_parameter" "subnet_list" {
  name = "/unity/account/network/subnet_list"
}

data "aws_ssm_parameter" "ecs_sg" {
  name = "/unity/account/eks/cluster_sg"
}

data "aws_ssm_parameter" "u-cs-ecs" {
  name = "/unity/account/ecs/execution_role_arn"
}

locals {
  subnet_map = jsondecode(data.aws_ssm_parameter.subnet_list.value)
  subnet_ids       = local.subnet_map["private"]
}


resource "aws_ecs_cluster" "httpd_cluster" {
  name = "httpd-cluster"
}

resource "aws_efs_file_system" "httpd_config_efs" {
  creation_token = "httpd-config"
}

resource "aws_efs_mount_target" "efs_mount_target" {
  for_each          = local.subnet_ids
  file_system_id     = aws_efs_file_system.httpd_config_efs.id
  subnet_id         = each.value
  security_groups    = ["sg-051a5abe923b5a595"]
}

resource "aws_ecs_task_definition" "httpd" {
  family                   = "httpd"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = data.aws_ssm_parameter.u-cs-ecs
  memory                   = "512"
  cpu                      = "256"
  volume {
    name = "httpd-config"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.httpd_config_efs.id
      root_directory          = "/"
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2049
    }
  }

  container_definitions = jsonencode([{
    name  = "httpd"
    image = "httpd:1.25.3" # Replace with your httpd image URL
    portMappings = [
      {
        containerPort = 8080
        hostPort      = 8080
      }
    ]
    mountPoints = [
      {
        containerPath = "/etc/apache2/sites-enabled/"
        sourceVolume  = "httpd-config"
      }
    ]
  }])
}

# Update the ECS Service to use the Load Balancer
resource "aws_ecs_service" "httpd_service" {
  name            = "httpd-service"
  cluster         = aws_ecs_cluster.httpd_cluster.id
  task_definition = aws_ecs_task_definition.httpd.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.httpd_tg.arn
    container_name   = "httpd"
    container_port   = 8080
  }

  network_configuration {
    subnets         = local.subnet_ids
    security_groups = [data.aws_ssm_parameter.ecs_sg]
    #needed so it can pull images
    assign_public_ip = true
  }

  depends_on = [
    aws_lb_listener.httpd_listener,
  ]
}

# Create an Application Load Balancer (ALB)
resource "aws_lb" "httpd_alb" {
  name               = "httpd-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.aws_ssm_parameter.ecs_sg] # Replace with the actual security group ID
  subnets            = local.subnet_ids
  enable_deletion_protection = false # Change to true if you want to prevent accidental deletion
}

# Create a Target Group for httpd
resource "aws_lb_target_group" "httpd_tg" {
  name     = "httpd-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_ssm_parameter.vpc_id
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
}
