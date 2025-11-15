ARG DOVECOT_VERSION="2.3.21.1-r0"
ARG DOVECOT_BASE_VERSION="2.3"
ARG PIGEONHOLE_VERSION="0.5.21"

# Stage: build Postgrey from source (Alpine)
FROM alpine:3.20 AS postgrey-builder

ARG POSTGREY_VERSION="1.37"
RUN apk add --no-cache \
        bash \
        build-base \
        curl \
        perl \
        perl-dev \
        perl-app-cpanminus \
        perl-dbi \
        perl-dbd-sqlite \
        perl-net-dns \
        perl-netaddr-ip \
        perl-net-ldap \
        perl-net-server \
        perl-io-socket-ssl \
        perl-io-socket-inet6 \
        perl-io-multiplex \
        perl-crypt-ssleay \
        perl-mozilla-ca \
        db-dev \
        tar
RUN cpanm --notest BerkeleyDB

RUN mkdir -p /build/postgrey && cd /build/postgrey && \
    curl -fsSL "http://deb.debian.org/debian/pool/main/p/postgrey/postgrey_${POSTGREY_VERSION}.orig.tar.gz" -o postgrey.tar.gz && \
    tar -xzf postgrey.tar.gz && cd postgrey-* && \
    install -Dm755 postgrey /postgrey-install/usr/sbin/postgrey && \
    install -Dm644 postgrey_whitelist_clients /postgrey-install/etc/postgrey/whitelist_clients && \
    install -Dm644 postgrey_whitelist_recipients /postgrey-install/etc/postgrey/whitelist_recipients && \
    install -Dm644 COPYING /postgrey-install/usr/share/licenses/postgrey/COPYING && \
    install -Dm644 README.md /postgrey-install/usr/share/doc/postgrey/README.md && \
    install -Dm644 README /postgrey-install/usr/share/doc/postgrey/README && \
    install -Dm755 contrib/postgrey.init /postgrey-install/usr/share/postgrey/postgrey.init

# Stage: build Dovecot pigeonhole from source
FROM alpine:3.20 AS pigeonhole-builder

ARG DOVECOT_VERSION
ARG DOVECOT_BASE_VERSION
ARG PIGEONHOLE_VERSION

RUN apk add --no-cache \
        bash \
        build-base \
        curl \
        dovecot=${DOVECOT_VERSION} \
        dovecot-dev=${DOVECOT_VERSION} \
        autoconf \
        automake \
        libtool \
        pkgconf \
        openssl-dev \
        zlib-dev \
        xz

RUN mkdir -p /build/pigeonhole \
      && cd /build/pigeonhole \
      && curl -fsSL "https://pigeonhole.dovecot.org/releases/${DOVECOT_BASE_VERSION}/dovecot-${DOVECOT_BASE_VERSION}-pigeonhole-${PIGEONHOLE_VERSION}.tar.gz" -o pigeonhole.tar.gz \
      && tar -xzf pigeonhole.tar.gz \
      && cd dovecot-${DOVECOT_BASE_VERSION}-pigeonhole-${PIGEONHOLE_VERSION} \
      && ./configure --prefix=/usr --with-dovecot=/usr/lib/dovecot \
      && make \
      && make DESTDIR=/pigeonhole-install install


# Stage: base tooling on Alpine
FROM alpine:3.20

ARG MAILINABOX_REPO_URL="https://github.com/mail-in-a-box/mailinabox.git"
ARG MAILINABOX_VERSION="v73"
# In container orchestration (e.g. Kubernetes), consider ingress-based protections instead of Fail2Ban.
ARG INSTALL_FAIL2BAN="false"
# In container orchestration (e.g. Kubernetes), or when you have infront nginx,
# you don't need local in-container Let's Encrypt. (set to false)
ARG WITH_SSL="true"
ARG ENABLE_INTERNAL_BIND="false"

ARG STORAGE_USER="user-data"
ARG STORAGE_ROOT="/home/user-data"

ARG PRIVATE_IP="127.0.0.1"
ARG PRIVATE_IPV6=""
ARG DEFAULT_MTA_STS_MODE="enforce"

ARG DOVECOT_VERSION
ARG DOVECOT_BASE_VERSION
ARG PIGEONHOLE_VERSION

ENV INSTALL_FAIL2BAN=${INSTALL_FAIL2BAN} \
    STORAGE_USER=${STORAGE_USER} \
    STORAGE_ROOT=${STORAGE_ROOT} \
    PRIVATE_IP=${PRIVATE_IP} \
    PRIVATE_IPV6=${PRIVATE_IPV6} \
    DEFAULT_MTA_STS_MODE=${DEFAULT_MTA_STS_MODE} \
    WITH_SSL=${WITH_SSL} \
    ENABLE_INTERNAL_BIND=${ENABLE_INTERNAL_BIND} \
    MAILINABOX_VERSION=${MAILINABOX_VERSION}

# Install runtime dependencies and git for cloning
RUN apk add --no-cache \
        bash \
        bc \
        build-base \
        ca-certificates \
        chrony \
        coreutils \
        curl \
        dcron \
        file \
        git \
        linux-headers \
        musl-locales \
        musl-locales-lang \
        netcat-openbsd \
        openssh-client \
        postfix \
        postfix-sqlite \
        postfix-pcre \
        python3 \
        python3-dev \
        py3-pip \
        py3-setuptools \
        py3-wheel \
        rsync \
        rsyslog \
        sudo \
        tar \
        tzdata \
        unzip \
        wget \
        xz

#Install pert needed by postgrey
RUN apk add --no-cache \
        perl \
        perl-dbi \
        perl-dbd-sqlite \
        perl-net-dns \
        perl-netaddr-ip \
        perl-net-ldap \
        perl-net-server \
        perl-io-socket-ssl \
        perl-io-socket-inet6 \
        perl-io-multiplex \
        perl-crypt-ssleay \
        perl-mozilla-ca \
        db

RUN apk add --no-cache \
        dovecot=${DOVECOT_VERSION} \
        dovecot-lmtpd=${DOVECOT_VERSION} \
        dovecot-sqlite=${DOVECOT_VERSION} \
        sqlite
# Dovecot packages on alpine include imap, pop3
# sieve is manually built from source in pigeonhole-builder stage

RUN apk add --no-cache \
        opendkim \
        opendkim-utils \
        opendmarc
# opendkim-utils contains the opendkim-genkey command

# duplicity is used to make backups of user data.
# virtualenv is used to isolate the Python 3 packages we
# install via pip from the system-installed packages (can be removed as we are in a container).
RUN apk add --no-cache \
        duplicity \
        py3-pip \
        py3-virtualenv \
        rsync

# Install libidn2 (library) and idn2-utils (provides idn2 command-line tool for IDN conversion)
RUN apk add --no-cache libidn2 idn2-utils


ARG S6_OVERLAY_VERSION="v3.1.5.0"
ARG S6_ARCH="x86_64"
ADD https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp/
ADD https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz /tmp/
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-${S6_ARCH}.tar.xz && \
    rm /tmp/s6-overlay-*.tar.xz

COPY --from=postgrey-builder /postgrey-install/ /
COPY --from=postgrey-builder /usr/local/lib/perl5/site_perl/ /usr/local/lib/perl5/site_perl/
COPY --from=postgrey-builder /usr/local/share/perl5/site_perl/ /usr/local/share/perl5/site_perl/
COPY --from=pigeonhole-builder /pigeonhole-install/ /

################################################################################
# Download Mail-in-a-Box management daemon dependencies and pre-requisites

# Install Mail-in-a-Box management daemon dependencies and assets
# Install b2sdk and boto3 system-wide (used by duplicity for backups)
RUN pip3 install --break-system-packages --upgrade b2sdk boto3

# Create virtualenv for management daemon Python packages
RUN mkdir -p /usr/local/lib/mailinabox && \
    virtualenv -ppython3 /usr/local/lib/mailinabox/env

# Install Python packages in virtualenv
RUN /usr/local/lib/mailinabox/env/bin/pip install --upgrade \
    rtyaml "email_validator>=1.0.0" "exclusiveprocess" \
    flask dnspython python-dateutil expiringdict gunicorn \
    qrcode[pil] pyotp \
    "idna>=2.0.0" "cryptography==37.0.2" psutil postfix-mta-sts-resolver \
    b2sdk boto3

# Download jQuery and Bootstrap assets with checksum verification
RUN mkdir -p /usr/local/lib/mailinabox/vendor/assets && \
    wget -O /usr/local/lib/mailinabox/vendor/assets/jquery.min.js \
        https://code.jquery.com/jquery-2.2.4.min.js && \
    echo "69bb69e25ca7d5ef0935317584e6153f3fd9a88c  /usr/local/lib/mailinabox/vendor/assets/jquery.min.js" | sha1sum -c --strict - && \
    wget -O /tmp/bootstrap.zip \
        https://github.com/twbs/bootstrap/releases/download/v3.4.1/bootstrap-3.4.1-dist.zip && \
    echo "0bb64c67c2552014d48ab4db81c2e8c01781f580  /tmp/bootstrap.zip" | sha1sum -c --strict - && \
    unzip -q /tmp/bootstrap.zip -d /usr/local/lib/mailinabox/vendor/assets && \
    mv /usr/local/lib/mailinabox/vendor/assets/bootstrap-3.4.1-dist /usr/local/lib/mailinabox/vendor/assets/bootstrap && \
    rm -f /tmp/bootstrap.zip

# End of Mail-in-a-Box management daemon dependencies and pre-requisites
################################################################################

# Optional SSL tooling
RUN if [ "${WITH_SSL}" = "true" ]; then \
        apk add --no-cache openssl certbot; \
    fi

# Prepare workspace
WORKDIR /opt

# Clone the specified release tag
RUN git clone --depth 1 --branch "${MAILINABOX_VERSION}" "${MAILINABOX_REPO_URL}" MailInABox

COPY mailinabox/setup/network-checks.sh /opt/MailInABox/setup/network-checks.sh
COPY mailinabox/setup/preflight.sh /opt/MailInABox/setup/preflight.sh
COPY mailinabox/setup/start.sh /opt/MailInABox/setup/start.sh
COPY mailinabox/setup/mail-postfix.sh /opt/MailInABox/setup/mail-postfix.sh
COPY mailinabox-patch/management/*.py /opt/MailInABox/management/
COPY mailinabox-config/ /opt/mailinabox-config/
COPY install/ /opt/install/
COPY entrypoint/ /opt/entrypoint/
COPY s6/ /etc/
RUN chmod +x /opt/install/*.sh /opt/entrypoint/*.sh /etc/cont-init.d/* /etc/services.d/*/run && \
    find /etc/services.d -name finish -type f -exec chmod +x {} \;

ENV IN_A_DOCKER=true

# Optional internal recursive DNS resolver packages
RUN if [ "${ENABLE_INTERNAL_BIND}" = "true" ]; then \
        apk add --no-cache bind bind-tools; \
        /bin/sh /opt/install/setup_bind.sh; \
    fi


WORKDIR /opt/MailInABox

# Prepare initial configuration
RUN /bin/sh /opt/install/prepare_conf.sh

# Optional Fail2Ban install & configuration
RUN /bin/sh /opt/install/setup_fail2ban.sh

# Generate default SSL assets (optional)
# Will be skipped if WITH_SSL is false.
RUN /bin/sh /opt/install/setup_ssl_base.sh

# Base Postfix installation/configuration (runtime-specific tweaks handled later).
RUN /bin/bash /opt/install/setup_mail_postfix_base.sh
# Base Dovecot installation/configuration.
RUN /bin/bash /opt/install/setup_mail_dovecot_base.sh
# Base DKIM installation/configuration.
RUN /bin/bash /opt/install/setup_dkim.sh
# Setup web
RUN /bin/sh /opt/install/setup_web_base.sh
# Install Mail-in-a-Box management daemon
RUN /bin/sh /opt/install/setup_mailinabox.sh

# Wait a maximum of 5 minutes for services to start
# It is needed because the SSL certificate generation can take several minutes:
# openssl dhparam -out "${STORAGE_ROOT}/ssl/dh2048.pem" 2048 can take several minutes
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=300000

ENTRYPOINT ["/init"]
CMD []

