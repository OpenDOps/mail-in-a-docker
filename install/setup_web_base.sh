#!/bin/bash
# HTTP: Turn on a web server serving static files
#################################################

source /opt/install/functions.sh # load our functions
source /etc/mailinabox.conf # load global vars

mkdir -p /var/lib/mailinabox/nginx-config

# Copy in a nginx configuration file for common and best-practices
# SSL settings from @konklone. Replace STORAGE_ROOT so it can find
# the DH params.
sed "s#STORAGE_ROOT#$STORAGE_ROOT#" \
	/opt/mailinabox-config/nginx-ssl.conf > /var/lib/mailinabox/nginx-config/ssl.conf


# We refeer to /etc/nginx/conf.d folder, because it will be mounted to it in the nginx container.
# This is needed because the nginx container is running as a separate container and we need to
# share the configuration files with it.
cat > /var/lib/mailinabox/nginx-config/nginx.conf <<EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  65;
    #gzip  on;

    server_names_hash_bucket_size 128;
    ssl_protocols TLSv1.2 TLSv1.3;

    include /etc/nginx/conf.d/ssl.conf;
    include /etc/nginx/conf.d/local.conf;
}
EOF

# Other nginx settings will be configured by the management service
# since it depends on what domains we're serving, which we don't know
# until mail accounts have been created.
