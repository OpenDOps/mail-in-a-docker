FROM alpine:3.20

RUN apk add --no-cache bash nsd ldns ldns-tools openssh-client coreutils tzdata logrotate dcron python3

COPY entrypoint/setup_nsd_runtime.sh /opt/install/setup_nsd.sh
COPY dns/nsd/entrypoint.sh /usr/local/bin/nsd-entrypoint.sh
COPY mailinabox/ /opt/MailInABox/

RUN chmod +x /opt/install/setup_nsd.sh /usr/local/bin/nsd-entrypoint.sh

VOLUME ["/etc/nsd", "/var/log", "/home/user-data"]

WORKDIR /opt/MailInABox

ENTRYPOINT ["/usr/local/bin/nsd-entrypoint.sh"]

