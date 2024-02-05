resource "aws_lambda_function" "my_lambda" {
  function_name = "${var.deployment_name}-httpdproxymanagement"

  filename      = "${path.module}/lambda.zip"
  handler       = "lambda.lambda_handler"
  runtime       = "python3.8"

  role          = aws_iam_role.lambda_iam_role.arn

  environment {
    variables = {
      CLUSTER_NAME = aws_ecs_cluster.httpd_cluster.name
      SERVICE_NAME = aws_ecs_service.httpd_service.name
    }
  }

  # EFS configuration
  file_system_config {
    arn = aws_efs_access_point.httpd_config_ap.arn
    local_mount_path = "/mnt/efs" # Lambda will access the EFS at this mount path
  }

  vpc_config {
    subnet_ids         = local.subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
  tags = {
    Service = "U-CS"
  }
}
resource "aws_security_group" "lambda_sg" {
  name        = "${var.deployment_name}-httpd_lambda_sg"
  description = "Security group for httpd lambda service"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  // Inbound rules
  // Example: Allow HTTP and HTTPS
  ingress {
    from_port   = 2049
    to_port     = 2049
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


resource "aws_iam_role" "lambda_iam_role" {
  name = "${var.deployment_name}-lambda_iam_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
      },
    ],
  })
  permissions_boundary = data.aws_iam_policy.mcp_operator_policy.arn

}

resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.deployment_name}-lambda_policy"
  description = "A policy for the Lambda function to access EFS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
        ],
        Effect = "Allow",
        Resource = [
          aws_efs_file_system.httpd_config_efs.arn
        ],
      },
    ],
  })

}

resource "aws_iam_policy" "lambda_ecs_stop_task_policy" {
  name        = "${var.deployment_name}-lambda_ecs_stop_task_policy"
  description = "Allows Lambda functions to stop ECS tasks"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["ecs:ListTasks","ecs:StopTask"],
        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_policy" "lambda_vpc_access_policy" {
  name        = "${var.deployment_name}-lambda_vpc_access_policy"
  description = "Allows Lambda functions to manage ENIs for VPC access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
        ],
        Resource = "*"
      },
    ],
  })
}
resource "aws_iam_role_policy_attachment" "lambda_vpc_access_policy_attachment" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = aws_iam_policy.lambda_vpc_access_policy.arn
}
resource "aws_iam_role_policy_attachment" "lambda_base_policy_attachment" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_stop_task_policy_attachment" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = aws_iam_policy.lambda_ecs_stop_task_policy.arn
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.my_lambda.arn
}

output "lambda_function_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.my_lambda.function_name
}