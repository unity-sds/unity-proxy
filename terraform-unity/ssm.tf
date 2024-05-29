resource "aws_ssm_parameter" "managementproxy_openvirtualhost" {
  name  = "/unity/${var.project}/${var.venue}/cs/management/proxy/configurations/001-openvirtualhost"
  type  = "String"
  value = <<-EOT
  <VirtualHost *:8080>
EOT
}

resource "aws_ssm_parameter" "managementproxy_closevirtualhost" {
  depends_on = [aws_ssm_parameter.managementproxy_openvirtualhost]
  name       = "/unity/${var.project}/${var.venue}/cs/management/proxy/configurations/100-closevirtualhost"
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

    RewriteEngine on
    RewriteCond %{HTTP:Upgrade} websocket [NC]
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteRule /management/(.*) ws://${var.mgmt_dns}/$1 [P,L]
    <Location "/management/">
        ProxyPass http://${var.mgmt_dns}/
        ProxyPassReverse http://${var.mgmt_dns}/
        ProxyPreserveHost On
        FallbackResource /management/index.html
    </Location>

EOT
}
