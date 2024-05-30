Unity Reverse Proxy

This proxy uses Apache HTTPD to proxy services from LB to backend web service.

To enable/disable modules, update and change the HTTPD installation then there is the Dockerfile to make these changes. 

The webservers default port is also 8080 to let it traverse the MCP NACL.

When deployed this terraform code creates an ECS cluster, with a baseline set of SSM parameters that other services can then extend with their own Apache HTTPD configurations. The configurations are pulled down and collated by the container on restart, so reloading of the configuration after changes is handled by triggering a lambda function.

A sample configuration snippet and trigger:
```
resource "aws_ssm_parameter" "managementproxy_config" {
  depends_on = [aws_ssm_parameter.managementproxy_closevirtualhost]
  name       = "/unity/${var.project}/${var.venue}/cs/management/proxy/configurations/010-management"
  type       = "String"
  value      = <<-EOT

    RewriteEngine on
    RewriteCond %%{HTTP:Upgrade} websocket [NC]
    RewriteCond %%{HTTP:Connection} upgrade [NC]
    RewriteRule /management/(.*) ws://${var.mgmt_dns}/$1 [P,L]
    <Location "/management/">
        ProxyPass http://${var.mgmt_dns}/
        ProxyPassReverse http://${var.mgmt_dns}/
        ProxyPreserveHost On
        FallbackResource /management/index.html
    </Location>

EOT
}

resource "aws_lambda_invocation" "demoinvocation2" {
  function_name = "${var.project}-${var.venue}-httpdproxymanagement"
}
```


The configuration is collated from SSM parameters residing under `/unity/${var.project}/${var.venue}/cs/management/proxy/configurations/`, and assembled like so:
```
<VirtualHost *:8080>

RewriteEngine on
RewriteCond %{HTTP:Upgrade} websocket [NC]
RewriteCond %{HTTP:Connection} upgrade [NC]
RewriteRule /management/(.*) ws://internal-unity-mc-alb-hzs9j-1269535099.us-west-2.elb.amazonaws.com:8080/$1 [P,L]
<Location "/management/">
    ProxyPass http://internal-unity-mc-alb-hzs9j-1269535099.us-west-2.elb.amazonaws.com:8080/
    ProxyPassReverse http://internal-unity-mc-alb-hzs9j-1269535099.us-west-2.elb.amazonaws.com:8080/
    ProxyPreserveHost On
    FallbackResource /management/index.html
</Location>

</VirtualHost>
```

Live checking of the "current" configuration may be accomplished with `write_site.py` in a local environment:
```
% DEBUG=yes UNITY_PROJECT=btlunsfo UNITY_VENUE=dev11  python write_site.py
<VirtualHost *:8080>

RewriteEngine on
RewriteCond %{HTTP:Upgrade} websocket [NC]
RewriteCond %{HTTP:Connection} upgrade [NC]
RewriteRule /management/(.*) ws://internal-unity-mc-alb-hzs9j-1269535099.us-west-2.elb.amazonaws.com:8080/$1 [P,L]
<Location "/management/">
    ProxyPass http://internal-unity-mc-alb-hzs9j-1269535099.us-west-2.elb.amazonaws.com:8080/
    ProxyPassReverse http://internal-unity-mc-alb-hzs9j-1269535099.us-west-2.elb.amazonaws.com:8080/
    ProxyPreserveHost On
    FallbackResource /management/index.html
</Location>

</VirtualHost>

```

This repository configures only one virtualhost (both open and close directives), but others may be added. This can be accomplished by simply adding more SSM parameters:
```
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
```
NOTE the names of each of these SSM parameters:
 - 001-openvirtualhost
 - 010-management
 - 100-closevirtualhost

For additional virtualhosts, please pick an ordinal number range that is *greater* than 100 (e.g. 101-openTestHost, 120-closeTestHost).

## How do I know what to add in the 'template' file above?
We are not perfect human beings. In order to iterate quickly on the above templat contents, we have created a development proxy environment that can be tested mostly locally. Check out the `develop` directory for instructions.
