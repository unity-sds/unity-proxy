# Unity Reverse Proxy

This proxy uses Apache HTTPD to proxy services from LB to backend web service.

To enable/disable modules, update and change the HTTPD installation in the Dockerfile to make these changes. 

The webservers default port is also 8080 to let it traverse the MCP NACL.

## How it works

When deployed this terraform code creates an ECS cluster, with a baseline set of SSM parameters that other services can then extend with their own Apache HTTPD configurations. The configurations are pulled down and collated by the container on restart, so reloading of the configuration after changes is handled by triggering a lambda function.

Below is an example configuration snippet and trigger. It includes some workarounds to accommodate an absolute-pathed web application, which may not be necessary for all applications.

Please note:
- the parameter name, espeially`0NN-servicename`
- the `var.service_endpoint`/`var.urlpath` used
- the 'value' of the ssm parameter
- the `depends_on` section (left empty)
```
resource "aws_ssm_parameter" "serviceproxy_config" {
  depends_on = []
  name       = "/unity/${var.project}/${var.venue}/cs/management/proxy/configurations/0NN-servicename"
  type       = "String"
  value       = <<-EOT

    <Location "/${var.urlpath}/">
      ProxyPassReverse "/"
    </Location>
    <LocationMatch "^/${var.urlpath}/(.*)$">
      ProxyPassMatch "http://${var.service_endpoint}/$1"
      ProxyPreserveHost On
      FallbackResource /management/index.html
      AddOutputFilterByType INFLATE;SUBSTITUTE;DEFLATE text/html
      Substitute "s|\"/([^\"]*)|\"/${var.urlpath}/$1|q"
    </LocationMatch>

EOT
}

resource "aws_lambda_invocation" "unity_proxy_lambda_invocation" {
  depends_on    = aws_ssm_parameter.serviceproxy_config
  function_name = "${var.project}-${var.venue}-httpdproxymanagement"
  input         = "{}"
  triggers = {
    redeployment = sha1(jsonencode([
      aws_ssm_parameter.serviceproxy_config
    ]))
  }
}
```
It's recommended to have the `aws_ssm_parameter.serviceproxy_config` depend on the last step of your service orchestration, so as to not set the proxy configuration up until everything has been orchestrated. The `aws_labda_invocation.unity_proxy_lambda_invocation` is configured above to trigger on any changes in the ssm parameter.

## Checking the current configuration

The configuration is collated from SSM parameters residing under `/unity/${var.project}/${var.venue}/cs/management/proxy/configurations/`, and assembled like so:
(this snipped contains just the management console proxy, which is usually set up by default with the unity-proxy instance)
```
<VirtualHost *:8080>

<Location "/management/">
    ProxyPass "http://internal-unity-mc-alb-hzs9j-1269535099.us-west-2.elb.amazonaws.com:8080/" upgrade=websocket
    ProxyPassReverse "http://internal-unity-mc-alb-hzs9j-1269535099.us-west-2.elb.amazonaws.com:8080/"
    ProxyPreserveHost On
    FallbackResource /management/index.html
</Location>

</VirtualHost>
```

Live checking of the "current" configuration may be accomplished with `write_site.py` in a local environment:
```
% DEBUG=yes UNITY_PROJECT=btlunsfo UNITY_VENUE=dev11  python write_site.py
<VirtualHost *:8080>

<Location "/management/">
    ProxyPass "http://internal-unity-mc-alb-hzs9j-1269535099.us-west-2.elb.amazonaws.com:8080/" upgrade=websocket
    ProxyPassReverse "http://internal-unity-mc-alb-hzs9j-1269535099.us-west-2.elb.amazonaws.com:8080/"
    ProxyPreserveHost On
    FallbackResource /management/index.html
</Location>

</VirtualHost>

```

## Ordering

This repository configures only one virtualhost listening on port 8080 (both open and close directives), but others may be added. This can be accomplished by simply adding more SSM parameters:
```
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
```
NOTE the names of each of these SSM parameters:
 - `001-openvhost8080`
 - `010-management`
 - `100-closevhost8080`

### For new services
Make sure to pick an unused numeric identifier between `001` and `100`- to ensure the collated httpd config places those inside of the :8080 Virtualhost (configured by `001-openvhost8080`/`100-closevhost8080`). Entries should be self-contained, and as such the ordering/chosen identifier of services shouldn't really matter besides those bounds.

### For additional virtualhosts
(for instance, listening on ports besides 8080)
Please pick an ordinal number range that is *greater* than 100 (e.g. 101-openTestHost, 120-closeTestHost).

## How do I know what to add in the 'template' file above?
We are not perfect human beings. In order to iterate quickly on the above templat contents, we have created a development proxy environment that can be tested mostly locally. Check out the `develop` directory for instructions.
