Unity Reverse Proxy

How to trigger:
```
resource "aws_lambda_invocation" "example_invocation2" {
  function_name = module.unity-proxy-CgbrD.lambda_function_name

  input = jsonencode({
    filename  = "example_filename1",
    template = "<VirtualHost *:8080>\nRewriteEngine on \n ProxyPass /management/ http://<DNS_NAME>/\n ProxyPassReverse /management/ http://<DNS_NAME>/ \n ProxyPreserveHost On \n RewriteCond {HTTP:Upgrade} websocket [NC] \n RewriteCond {HTTP:Connection} upgrade [NC] \n RewriteRule /management/(.*) ws://<DNS_NAME>/$1 [P,L] \n FallbackResource /management/index.html \n </VirtualHost>"
  })

  # Depends on ensures that the Lambda function is created before it is invoked.
  depends_on = [module.unity-proxy-CgbrD]
}
```
