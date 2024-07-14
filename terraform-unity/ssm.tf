resource "aws_ssm_parameter" "managementproxy_openvirtualhost" {
  name  = "/unity/${var.project}/${var.venue}/cs/management/proxy/configurations/001-openvhost8080"
  type  = "String"
  value = <<-EOT
  <VirtualHost *:8080>
EOT
}

resource "aws_ssm_parameter" "managementproxy_closevirtualhost" {
  depends_on = [aws_ssm_parameter.managementproxy_openvirtualhost]
  name       = "/unity/${var.project}/${var.venue}/cs/management/proxy/configurations/100-closevhost8080"
  type       = "String"
  value      = <<-EOT
  </VirtualHost>
EOT
}

resource "aws_ssm_parameter" "managementproxy_config" {
  depends_on = [aws_ssm_parameter.managementproxy_closevirtualhost]
  name       = "/unity/${var.project}/${var.venue}/cs/management/proxy/configurations/010-management"
  type       = "String"
  value      = <<-EOT

    <Location "/management/">
        ProxyPass "http://${var.mgmt_dns}/" upgrade=websocket
        ProxyPassReverse "http://${var.mgmt_dns}/"
        ProxyPreserveHost On
        FallbackResource /management/index.html
    </Location>

EOT
}
