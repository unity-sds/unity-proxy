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
cat <<EOF > "${file_path}"
RewriteEngine on
ProxyPass /management/ http://${ELB_DNS_NAME}/
ProxyPassReverse /management/ http://${ELB_DNS_NAME}/
ProxyPreserveHost On
RewriteCond %{HTTP:Upgrade} websocket [NC]
RewriteCond %{HTTP:Connection} upgrade [NC]
RewriteRule /management/(.*) ws://${ELB_DNS_NAME}/\$1 [P,L]

FallbackResource /management/index.html
EOF

echo "VirtualHost configuration written to: $file_path"

main_template='
<VirtualHost *:8080>
    Include /etc/apache2/sites-enabled/mgmt.conf
    ### ADD MORE HOSTS BELOW THIS LINE

</VirtualHost>
'

echo "$main_template" > "$main_path"
echo "Main configuration written to: $main_path"

chown 1000:1000 /etc/apache2/sites-enabled/main.conf
chmod 755 /etc/apache2/sites-enabled/main.conf