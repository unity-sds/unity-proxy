provider "aws" {
  region = "us-west-2"
}

data "aws_vpc" "existing_vpc" {
  id = "vpc-0106218dbddd3a753" # Replace with your actual VPC ID
}

# Data source to gather all subnets associated with the specified VPC
data "aws_subnets" "existing_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing_vpc.id]
  }
}

data "aws_subnet" "selected_subnets" {
  for_each = toset(data.aws_subnets.existing_subnets.ids)
  id       = each.value
}

resource "aws_ecs_cluster" "httpd_cluster" {
  name = "httpd-cluster"
}

resource "aws_efs_file_system" "httpd_config_efs" {
  creation_token = "httpd-config"
}

resource "aws_efs_mount_target" "efs_mount_target" {
  for_each          = toset(data.aws_subnets.existing_subnets.ids)
  file_system_id     = aws_efs_file_system.httpd_config_efs.id
  subnet_id         = each.value
  security_groups    = ["sg-051a5abe923b5a595"]
}

resource "aws_ecs_task_definition" "httpd" {
  family                   = "httpd"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = "arn:aws:iam::237868187491:role/u-cs-ecs-use-eks"
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
    subnets         = data.aws_subnets.existing_subnets.ids
    security_groups = ["sg-051a5abe923b5a595"]
    assign_public_ip = true
  }

  depends_on = [
    aws_lb_listener.httpd_listener,
  ]
}

locals {
  # This will group subnets by their AZs into a list
  subnets_by_az = { for s in data.aws_subnet.selected_subnets : s.availability_zone => s... }

  # This will pick the first subnet ID from each grouped AZ list
  unique_az_subnets = [for az, subnets in local.subnets_by_az : subnets[0].id]
}

# Create an Application Load Balancer (ALB)
resource "aws_lb" "httpd_alb" {
  name               = "httpd-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["sg-051a5abe923b5a595"] # Replace with the actual security group ID
  subnets            = local.unique_az_subnets
  enable_deletion_protection = false # Change to true if you want to prevent accidental deletion
}

# Create a Target Group for httpd
resource "aws_lb_target_group" "httpd_tg" {
  name     = "httpd-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.existing_vpc.id
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