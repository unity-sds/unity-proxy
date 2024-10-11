resource "aws_ecs_cluster" "httpd_cluster" {
  name = "${var.project}-${var.venue}-httpd-cluster"
  tags = {
    Service = "U-CS"
  }
}

data "aws_iam_policy" "mcp_operator_policy" {
  name = "mcp-tenantOperator-AMI-APIG"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project}-${var.venue}-ecs_task_role"

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

resource "aws_iam_role_policy_attachment" "ecs_ssm_role_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project}-${var.venue}ecs_execution_role"

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
  name = "/ecs/${var.project}-${var.venue}-managementproxy"
}

resource "aws_ecs_task_definition" "httpd" {
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  family                   = "httpd"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  memory                   = "512"
  cpu                      = "256"


  container_definitions = jsonencode([{
    name  = "${var.project}-${var.venue}-httpd-task"
    image = "ghcr.io/unity-sds/unity-proxy/httpd-proxy:${var.httpd_proxy_version}"
    environment = [
      {
        name  = "UNITY_PROJECT",
        value = var.project
      },
      {
        name  = "UNITY_VENUE",
        value = var.venue
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
  }])
  tags = {
    Service = "U-CS"
  }
}

resource "aws_security_group" "ecs_sg" {
  name        = "${var.project}-${var.venue}-ecs_service_sg"
  description = "Security group for ECS service"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value
  tags = {
    Service = "U-CS"
  }
}

resource "aws_security_group" "ecs_alb_sg" {
  name        = "${var.project}-${var.venue}-ecs_alb_sg"
  description = "Security group for ECS service ALB"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value
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
    container_name   = "${var.project}-${var.venue}-httpd-task"
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
    aws_ssm_parameter.managementproxy_config
  ]
}

# Find the MC's ALB's security group (created before unity-proxy)
data "aws_security_group" "mc_alb_sg" {
  tags = {
    Name        = "Unity Management Console Load Balancer SG"
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

# Add a new ingress rule to the ECS ALB's security group, opening it up to other connections
#tfsec:ignore:AVD-AWS-0107
resource "aws_vpc_security_group_ingress_rule" "alb_all_ingress_sg_rule" {
  security_group_id = aws_security_group.ecs_alb_sg.id
  to_port           = 8080
  from_port         = 8080
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}