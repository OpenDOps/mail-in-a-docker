FROM alpine:3.20

RUN apk add --no-cache bash bind bind-tools coreutils tzdata

COPY install/setup_bind.sh /opt/install/setup_bind.sh
COPY dns/bind/entrypoint.sh /usr/local/bin/bind-entrypoint.sh

RUN chmod +x /opt/install/setup_bind.sh /usr/local/bin/bind-entrypoint.sh

VOLUME ["/var/bind"]

WORKDIR /opt/install

ENTRYPOINT ["/usr/local/bin/bind-entrypoint.sh"]
CMD ["named", "-f", "-u", "named", "-c", "/etc/bind/named.conf"]

