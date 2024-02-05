resource "aws_efs_file_system" "httpd_config_efs" {
  creation_token = "${var.deployment_name}-httpd-config"
  tags = {
    Service = "U-CS"
  }
}
resource "aws_security_group" "efs_sg" {
  name        = "${var.deployment_name}-efs-security-group"
  description = "Security group for EFS"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  # Ingress rule to allow NFS
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    security_groups  = [aws_security_group.ecs_sg.id, aws_security_group.lambda_sg.id]
  }

  # Egress rule - allowing all outbound traffic
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
resource "aws_efs_mount_target" "efs_mount_target" {
  for_each          = toset(local.subnet_ids)
  file_system_id     = aws_efs_file_system.httpd_config_efs.id
  subnet_id         = each.value
  security_groups    = [aws_security_group.efs_sg.id]
}


resource "aws_efs_access_point" "httpd_config_ap" {
  file_system_id = aws_efs_file_system.httpd_config_efs.id

  posix_user {
    gid = 1001
    uid = 1001
  }

  root_directory {
    path = "/"
    creation_info {
      owner_gid   = 1001
      owner_uid   = 1001
      permissions = "0755"
    }
  }

  tags = {
    Name = "${var.deployment_name}-httpd-config-ap"
    Service = "U-CS"
  }
}