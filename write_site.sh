#!/bin/bash

# Define the EFS mount point
efs_mount_point="/etc/apache2/sites-enabled"

# Check if the EFS mount point exists
if [ ! -d "$efs_mount_point" ]; then
    echo "EFS mount point not found: $efs_mount_point"
    exit 1
fi

# File to be written
file_path="$efs_mount_point/mgmt.conf"
main_path="$efs_mount_point/main.conf"
# Ensure the ELB_DNS_NAME environment variable is set
if [ -z "$ELB_DNS_NAME" ]; then
    echo "ELB_DNS_NAME environment variable is not set"
    exit 1
fi

# VirtualHost template with placeholder for DNS_NAME
vhost_template='
RewriteEngine on
ProxyPass /management/ http://<DNS_NAME>/
ProxyPassReverse /management/ http://<DNS_NAME>/
ProxyPreserveHost On
RewriteCond %{HTTP:Upgrade} websocket [NC]
RewriteCond %{HTTP:Connection} upgrade [NC]
RewriteRule /management/(.*) ws://<DNS_NAME>/$1 [P,L]

FallbackResource /management/index.html
'

# Replace <DNS_NAME> with actual DNS name
vhost_config="${vhost_template//<DNS_NAME>/$ELB_DNS_NAME}"

# Write the configuration to the file
echo "$vhost_config" > "$file_path"

echo "VirtualHost configuration written to: $file_path"

main_template='
<VirtualHost *:8080>
    Include /etc/apache2/sites-enabled/mgmt.conf
    ### ADD MORE HOSTS BELOW THIS LINE

</VirtualHost>
'

echo "$main_template" > "$main_path"