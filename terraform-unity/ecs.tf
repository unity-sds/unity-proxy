resource "aws_ecs_cluster" "httpd_cluster" {
  name = "${var.deployment_name}-httpd-cluster"
  tags = {
    Service = "U-CS"
  }
}

data "aws_iam_policy" "mcp_operator_policy" {
  name = "mcp-tenantOperator-AMI-APIG"
}

resource "aws_iam_policy" "efs_access" {
  name        = "${var.deployment_name}-EFSAccessPolicy"
  description = "Policy for ECS tasks to access EFS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess",
          "elasticfilesystem:DescribeMountTargets",
        ],
        Resource = "*",
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "efs_access_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.efs_access.arn
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.deployment_name}-ecs_task_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole",
      },
    ],
  })
  permissions_boundary = data.aws_iam_policy.mcp_operator_policy.arn

}

resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.deployment_name}ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  permissions_boundary = data.aws_iam_policy.mcp_operator_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_cloudwatch_log_group" "proxyloggroup" {
  name = "/ecs/${var.deployment_name}-managementproxy"
}

resource "aws_ecs_task_definition" "httpd" {
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  family                   = "httpd"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  memory                   = "512"
  cpu                      = "256"
  volume {
    name = "httpd-config"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.httpd_config_efs.id
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2049
      authorization_config {
        access_point_id = aws_efs_access_point.httpd_config_ap.id
        iam = "ENABLED"
      }
    }
  }


  container_definitions = jsonencode([{
    name  = "httpd"
    image = "ghcr.io/unity-sds/unity-proxy/httpd-proxy:0.13.0"
    environment = [
      {
        name = "ELB_DNS_NAME",
        value = var.mgmt_dns
      }
    ]
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        awslogs-group         = aws_cloudwatch_log_group.proxyloggroup.name,
        awslogs-region        = "us-west-2",
        awslogs-stream-prefix = "ecs"
      },
    },
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
  tags = {
    Service = "U-CS"
  }
}

resource "aws_security_group" "ecs_sg" {
  name        = "${var.deployment_name}-ecs_service_sg"
  description = "Security group for ECS service"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  // Inbound rules
  // Example: Allow HTTP and HTTPS
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Outbound rules
  // Example: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Service = "U-CS"
  }
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
    security_groups = [aws_security_group.ecs_sg.id]
    #needed so it can pull images
    assign_public_ip = true
  }
  tags = {
    Service = "U-CS"
  }
  depends_on = [
    aws_lb_listener.httpd_listener,
  ]
}
