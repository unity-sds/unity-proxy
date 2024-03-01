Unity Reverse Proxy

This proxy uses Apache HTTPD to proxy services from LB to backend web service.

To enable/disable modules, update and change the HTTPD installation then there is the Dockerfile to make these changes. 

The webservers default port is also 8080 to let it traverse the MCP NACL.

When deployed this terraform code creates an ECS cluster, with an EFS backend that then allows us to store apache configs
in a filesystem that wont vanish when it restarts. As such the EFS filesystem also needs a way to create new files, this is
done via a lambda function that writes valid apache config files to the EFS mount.

A sample trigger:
```
variable "template" {
  default = <<EOT
                  RewriteEngine on
                  ProxyPass /sample http://test-demo-alb-616613476.us-west-2.elb.amazonaws.com:8888/sample/hello.jsp
                  ProxyPassReverse /sample http://test-demo-alb-616613476.us-west-2.elb.amazonaws.com:8888/sample/hello.jsp

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
The config files are written as flat configs. They are then used inside a main apache2 config like this:

```
<VirtualHost *:8080>
    Include /etc/apache2/sites-enabled/mgmt.conf
    ### ADD MORE HOSTS BELOW THIS LINE

</VirtualHost>
```

They will be added as additional config files below the comment line. The httpd task is then restarted to allow the 
config to then take effect.

There is currently no way to remove files or fix a broken config other than mounting the EFS mount into an EC2 server and making changes.
To do this you will need to edit the security group to allow access to the EC2 box and then install the EFS utils.
