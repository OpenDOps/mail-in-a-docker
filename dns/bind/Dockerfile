FROM alpine:3.20

# Pin package versions for security (prevents supply chain attacks)
RUN apk add --no-cache \
        bash=5.2.26-r0 \
        bind=9.18.41-r0 \
        bind-tools=9.18.41-r0 \
        coreutils=9.5-r2 \
        tzdata=2025b-r0

COPY install/setup_bind.sh /opt/install/setup_bind.sh
COPY dns/bind/entrypoint.sh /usr/local/bin/bind-entrypoint.sh

RUN chmod +x /opt/install/setup_bind.sh /usr/local/bin/bind-entrypoint.sh

VOLUME ["/var/bind"]

WORKDIR /opt/install

ENTRYPOINT ["/usr/local/bin/bind-entrypoint.sh"]
CMD ["named", "-f", "-u", "named", "-c", "/etc/bind/named.conf"]
