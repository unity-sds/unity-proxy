Unity Reverse Proxy

How to trigger:
```
variable "template" {
  default = <<EOT
<VirtualHost *:8080>
                  RewriteEngine on
                  ProxyPass /sample http://test-demo-alb-616613476.us-west-2.elb.amazonaws.com:8888/sample/hello.jsp
                  ProxyPassReverse /sample http://test-demo-alb-616613476.us-west-2.elb.amazonaws.com:8888/sample/hello.jsp
</VirtualHost>
EOT
}

resource "aws_lambda_invocation" "demoinvocation2" {
  function_name = "ZwUycV-unity-proxy-httpdproxymanagement"

  input = jsonencode({
    filename  = "example_filename1",
    template = var.template
  })

}
```
