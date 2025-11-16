FROM alpine:3.20

# Pin package versions for security (prevents supply chain attacks)
RUN apk add --no-cache \
        bash=5.2.26-r0 \
        nsd=4.9.1-r0 \
        ldns=1.8.3-r2 \
        ldns-tools=1.8.3-r2 \
        openssh-client-default=9.7_p1-r5 \
        coreutils=9.5-r2 \
        tzdata=2025b-r0 \
        logrotate=3.21.0-r1 \
        dcron=4.5-r9 \
        python3=3.12.12-r0

COPY entrypoint/setup_nsd_runtime.sh /opt/install/setup_nsd.sh
COPY dns/nsd/entrypoint.sh /usr/local/bin/nsd-entrypoint.sh

RUN chmod +x /opt/install/setup_nsd.sh /usr/local/bin/nsd-entrypoint.sh

VOLUME ["/etc/nsd", "/var/log", "/home/user-data"]

WORKDIR /opt/MailInABox

ENTRYPOINT ["/usr/local/bin/nsd-entrypoint.sh"]
