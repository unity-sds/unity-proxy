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

    <Location "/${var.project}/${var.venue}/management/">
        ProxyPass "http://${var.mgmt_dns}/" upgrade=websocket retry=5 disablereuse=On
        ProxyPassReverse "http://${var.mgmt_dns}/"
        ProxyPreserveHost On
        FallbackResource /management/index.html
        AddOutputFilterByType INFLATE;SUBSTITUTE;DEFLATE text/html text/javascript
        Substitute "s|management/ws|${var.project}/${var.venue}/management/ws|n"
        Substitute "s|\"/([^\"]+)\"(?!:)|\"/${var.project}/${var.venue}/$1\"|q"
    </Location>

EOT
}
