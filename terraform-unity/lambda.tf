resource "aws_lambda_function" "my_lambda" {
  function_name = "my_lambda_function"

  # Assuming the lambda.zip file is in the same directory as your Terraform configuration
  filename      = "${path.module}/lambda.zip"
  handler       = "lambda.lambda_handler" # Update the handler accordingly
  runtime       = "python3.8" # Update the runtime as necessary

  role          = aws_iam_role.lambda_iam_role.arn

  environment {
    variables = {
      CLUSTER_NAME = aws_ecs_cluster.httpd_cluster.name
      TASK_ID      = aws_ecs_task_definition.httpd.id
    }
  }

  # EFS configuration
  file_system_config {
    arn = aws_efs_file_system.httpd_config_efs.arn
    local_mount_path = "/mnt/efs" # Lambda will access the EFS at this mount path
  }
}

resource "aws_iam_role" "lambda_iam_role" {
  name = "lambda_iam_role"

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
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
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
  permissions_boundary = data.aws_iam_policy.mcp_operator_policy.arn

}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}