FROM alpine:3.20

# Pin package versions for security (prevents supply chain attacks)
RUN apk add --no-cache \
        bash=5.2.26-r0 \
        bind=9.18.41-r0 \
        bind-tools=9.18.41-r0 \
        bind-plugins=9.18.41-r0 \
        coreutils=9.5-r2 \
        tzdata=2025b-r0 \
        wget=1.24.5-r0 \
        curl=8.14.1-r2 \
        jq=1.7.1-r0 \
        dcron=4.5-r9

# Download root hints from IANA (official source) at build time
RUN mkdir -p /usr/share/dns && \
    wget -q -O /usr/share/dns/root.hints https://www.internic.net/domain/named.root || \
    (echo "Warning: Failed to download root hints, creating minimal version" && \
     printf '.                        3600000  IN  NS    A.ROOT-SERVERS.NET.\nA.ROOT-SERVERS.NET.      3600000  A     198.41.0.4\nA.ROOT-SERVERS.NET.      3600000  AAAA  2001:503:ba3e::2:30\n' > /usr/share/dns/root.hints)

RUN mkdir -p /etc/bind-tmp
# Generate rndc key for remote control
RUN rndc-confgen -a -k rndc-key -c /etc/bind-tmp/rndc.key && \
    chmod 640 /etc/bind-tmp/rndc.key && \
    chown root:named /etc/bind-tmp/rndc.key

COPY install/setup_bind.sh /opt/install/setup_bind.sh
COPY dns/bind/entrypoint.sh /usr/local/bin/bind-entrypoint.sh
COPY dns/bind/refresh_nta.sh /usr/local/bin/refresh_nta.sh

RUN chmod +x /opt/install/setup_bind.sh /usr/local/bin/bind-entrypoint.sh /usr/local/bin/refresh_nta.sh

ENV IN_A_DOCKER=true

VOLUME ["/var/bind"]

WORKDIR /opt/install

ENTRYPOINT ["/usr/local/bin/bind-entrypoint.sh"]
CMD ["named", "-f", "-u", "named", "-c", "/etc/bind/named.conf"]
