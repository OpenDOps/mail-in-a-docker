ARG DOVECOT_VERSION="2.3.21.1-r0"
ARG DOVECOT_BASE_VERSION="2.3"
ARG PIGEONHOLE_VERSION="0.5.21"

# Pin package versions for security (prevents supply chain attacks)
# These versions are reused across multiple build stages
ARG BASH_VERSION="5.2.26-r0"
ARG BUILD_BASE_VERSION="0.5-r3"
ARG CURL_VERSION="8.14.1-r2"
ARG TAR_VERSION="1.35-r2"
ARG PERL_VERSION="5.38.5-r0"
ARG PERL_DEV_VERSION="5.38.5-r0"
ARG PERL_APP_CPANMINUS_VERSION="1.7047-r0"
ARG PERL_DBI_VERSION="1.643-r6"
ARG PERL_DBD_SQLITE_VERSION="1.74-r0"
ARG PERL_NET_DNS_VERSION="1.45-r0"
ARG PERL_NETADDR_IP_VERSION="4.079-r12"
ARG PERL_LDAP_VERSION="0.68-r2"
ARG PERL_NET_SERVER_VERSION="2.014-r2"
ARG PERL_IO_SOCKET_SSL_VERSION="2.085-r0"
ARG PERL_IO_SOCKET_INET6_VERSION="2.73-r2"
ARG PERL_IO_MULTIPLEX_VERSION="1.16-r5"
ARG PERL_CRYPT_SSLEAY_VERSION="0.72-r21"
ARG PERL_MOZILLA_CA_VERSION="20240313-r0"
ARG DB_VERSION="5.3.28-r5"
ARG DB_DEV_VERSION="5.3.28-r5"
ARG AUTOCONF_VERSION="2.72-r0"
ARG AUTOMAKE_VERSION="1.16.5-r2"
ARG LIBTOOL_VERSION="2.4.7-r3"
ARG PKGCONF_VERSION="2.2.0-r0"
ARG OPENSSL_DEV_VERSION="3.3.5-r0"
ARG OPENSSL_VERSION="3.3.5-r0"
ARG ZLIB_DEV_VERSION="1.3.1-r1"
ARG XZ_VERSION="5.6.2-r1"
ARG BC_VERSION="1.07.1-r4"
ARG CA_CERTIFICATES_VERSION="20250911-r0"
ARG CHRONY_VERSION="4.5-r0"
ARG COREUTILS_VERSION="9.5-r2"
ARG DCRON_VERSION="4.5-r9"
ARG FILE_VERSION="5.45-r1"
ARG GIT_VERSION="2.45.4-r0"
ARG LINUX_HEADERS_VERSION="6.6-r0"
ARG MUSL_LOCALES_VERSION="0.1.0-r1"
ARG MUSL_LOCALES_LANG_VERSION="0.1.0-r1"
ARG NETCAT_OPENBSD_VERSION="1.226-r0"
ARG OPENSSH_CLIENT_VERSION="9.7_p1-r5"
ARG POSTFIX_VERSION="3.9.6-r0"
ARG POSTFIX_SQLITE_VERSION="3.9.6-r0"
ARG POSTFIX_PCRE_VERSION="3.9.6-r0"
ARG PYTHON3_VERSION="3.12.12-r0"
ARG PYTHON3_DEV_VERSION="3.12.12-r0"
ARG PY3_PIP_VERSION="24.0-r2"
ARG PY3_SETUPTOOLS_VERSION="70.3.0-r0"
ARG PY3_WHEEL_VERSION="0.42.0-r1"
ARG RSYNC_VERSION="3.4.1-r1"
ARG RSYSLOG_VERSION="8.2404.0-r0"
ARG SUDO_VERSION="1.9.15_p5-r0"
ARG TZDATA_VERSION="2025b-r0"
ARG UNZIP_VERSION="6.0-r14"
ARG WGET_VERSION="1.24.5-r0"
ARG SQLITE_VERSION="3.45.3-r2"
ARG OPENDKIM_VERSION="2.11.0-r3"
ARG OPENDKIM_UTILS_VERSION="2.11.0-r3"
ARG OPENDMARC_VERSION="1.4.2-r1"
ARG DUPLICITY_VERSION="2.2.3-r1"
ARG PY3_VIRTUALENV_VERSION="20.28.0-r0"
ARG LIBIDN2_VERSION="2.3.7-r0"
ARG IDN2_UTILS_VERSION="2.3.7-r0"
ARG CERTBOT_VERSION="2.10.0-r1"
ARG BIND_VERSION="9.18.41-r0"
ARG BIND_TOOLS_VERSION="9.18.41-r0"

# Stage: build Postgrey from source (Alpine)
FROM alpine:3.20 AS postgrey-builder

# Set SHELL with pipefail for better error handling in RUN commands with pipes
SHELL ["/bin/sh", "-o", "pipefail", "-c"]

# Redeclare ARG variables for this stage (required for multi-stage builds)
ARG BASH_VERSION
ARG BUILD_BASE_VERSION
ARG CURL_VERSION
ARG TAR_VERSION
ARG PERL_DEV_VERSION
ARG PERL_APP_CPANMINUS_VERSION
ARG PERL_DBI_VERSION
ARG PERL_DBD_SQLITE_VERSION
ARG PERL_NET_DNS_VERSION
ARG PERL_NETADDR_IP_VERSION
ARG PERL_LDAP_VERSION
ARG PERL_NET_SERVER_VERSION
ARG PERL_IO_SOCKET_SSL_VERSION
ARG PERL_IO_SOCKET_INET6_VERSION
ARG PERL_IO_MULTIPLEX_VERSION
ARG PERL_CRYPT_SSLEAY_VERSION
ARG PERL_MOZILLA_CA_VERSION
ARG DB_DEV_VERSION

ARG POSTGREY_VERSION="1.37"
# Pin package versions for security (prevents supply chain attacks)
# To update versions: Run ./scripts/pin-package-versions.sh <package> to get current versions
RUN apk add --no-cache \
        bash=${BASH_VERSION} \
        build-base=${BUILD_BASE_VERSION} \
        curl=${CURL_VERSION} \
        perl=${PERL_DEV_VERSION} \
        perl-dev=${PERL_DEV_VERSION} \
        perl-app-cpanminus=${PERL_APP_CPANMINUS_VERSION} \
        perl-dbi=${PERL_DBI_VERSION} \
        perl-dbd-sqlite=${PERL_DBD_SQLITE_VERSION} \
        perl-net-dns=${PERL_NET_DNS_VERSION} \
        perl-netaddr-ip=${PERL_NETADDR_IP_VERSION} \
        perl-ldap=${PERL_LDAP_VERSION} \
        perl-net-server=${PERL_NET_SERVER_VERSION} \
        perl-io-socket-ssl=${PERL_IO_SOCKET_SSL_VERSION} \
        perl-io-socket-inet6=${PERL_IO_SOCKET_INET6_VERSION} \
        perl-io-multiplex=${PERL_IO_MULTIPLEX_VERSION} \
        perl-crypt-ssleay=${PERL_CRYPT_SSLEAY_VERSION} \
        perl-mozilla-ca=${PERL_MOZILLA_CA_VERSION} \
        db-dev=${DB_DEV_VERSION} \
        tar=${TAR_VERSION}
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

# Set SHELL with pipefail for better error handling in RUN commands with pipes
SHELL ["/bin/sh", "-o", "pipefail", "-c"]

ARG DOVECOT_VERSION
ARG DOVECOT_BASE_VERSION
ARG PIGEONHOLE_VERSION

ARG BASH_VERSION
ARG BUILD_BASE_VERSION
ARG CURL_VERSION
ARG AUTOCONF_VERSION
ARG AUTOMAKE_VERSION
ARG LIBTOOL_VERSION
ARG PKGCONF_VERSION
ARG OPENSSL_DEV_VERSION
ARG ZLIB_DEV_VERSION
ARG XZ_VERSION

# We need to use bash for the build process, so we 'ln -sf /bin/bash /bin/sh'
#hadolint ignore=DL4005
RUN apk add --no-cache \
        bash=${BASH_VERSION} \
        build-base=${BUILD_BASE_VERSION} \
        curl=${CURL_VERSION} \
        dovecot=${DOVECOT_VERSION} \
        dovecot-dev=${DOVECOT_VERSION} \
        autoconf=${AUTOCONF_VERSION} \
        automake=${AUTOMAKE_VERSION} \
        libtool=${LIBTOOL_VERSION} \
        pkgconf=${PKGCONF_VERSION} \
        openssl-dev=${OPENSSL_DEV_VERSION} \
        zlib-dev=${ZLIB_DEV_VERSION} \
        xz=${XZ_VERSION} \
    && ln -sf /bin/bash /bin/sh

RUN mkdir -p /build/pigeonhole \
      && cd /build/pigeonhole \
      && curl -fsSL "https://pigeonhole.dovecot.org/releases/${DOVECOT_BASE_VERSION}/dovecot-${DOVECOT_BASE_VERSION}-pigeonhole-${PIGEONHOLE_VERSION}.tar.gz" -o pigeonhole.tar.gz \
      && tar -xzf pigeonhole.tar.gz \
      && cd dovecot-${DOVECOT_BASE_VERSION}-pigeonhole-${PIGEONHOLE_VERSION} \
      && autoreconf -fiv \
      && ./configure --prefix=/usr --with-dovecot=/usr/lib/dovecot \
      && make \
      && make DESTDIR=/pigeonhole-install install


# Stage: base tooling on Alpine
FROM alpine:3.20

# Set SHELL with pipefail for better error handling in RUN commands with pipes
SHELL ["/bin/sh", "-o", "pipefail", "-c"]

# Redeclare all ARG variables for this stage (required for multi-stage builds)
ARG BASH_VERSION
ARG BUILD_BASE_VERSION
ARG CURL_VERSION
ARG TAR_VERSION
ARG PERL_VERSION
ARG PERL_DEV_VERSION
ARG PERL_APP_CPANMINUS_VERSION
ARG PERL_DBI_VERSION
ARG PERL_DBD_SQLITE_VERSION
ARG PERL_NET_DNS_VERSION
ARG PERL_NETADDR_IP_VERSION
ARG PERL_LDAP_VERSION
ARG PERL_NET_SERVER_VERSION
ARG PERL_IO_SOCKET_SSL_VERSION
ARG PERL_IO_SOCKET_INET6_VERSION
ARG PERL_IO_MULTIPLEX_VERSION
ARG PERL_CRYPT_SSLEAY_VERSION
ARG PERL_MOZILLA_CA_VERSION
ARG DB_VERSION
ARG DB_DEV_VERSION
ARG AUTOCONF_VERSION
ARG AUTOMAKE_VERSION
ARG LIBTOOL_VERSION
ARG PKGCONF_VERSION
ARG OPENSSL_DEV_VERSION
ARG OPENSSL_VERSION
ARG ZLIB_DEV_VERSION
ARG XZ_VERSION
ARG BC_VERSION
ARG CA_CERTIFICATES_VERSION
ARG CHRONY_VERSION
ARG COREUTILS_VERSION
ARG DCRON_VERSION
ARG FILE_VERSION
ARG GIT_VERSION
ARG LINUX_HEADERS_VERSION
ARG MUSL_LOCALES_VERSION
ARG MUSL_LOCALES_LANG_VERSION
ARG NETCAT_OPENBSD_VERSION
ARG OPENSSH_CLIENT_VERSION
ARG POSTFIX_VERSION
ARG POSTFIX_SQLITE_VERSION
ARG POSTFIX_PCRE_VERSION
ARG PYTHON3_VERSION
ARG PYTHON3_DEV_VERSION
ARG PY3_PIP_VERSION
ARG PY3_SETUPTOOLS_VERSION
ARG PY3_WHEEL_VERSION
ARG RSYNC_VERSION
ARG RSYSLOG_VERSION
ARG SUDO_VERSION
ARG TZDATA_VERSION
ARG UNZIP_VERSION
ARG WGET_VERSION
ARG SQLITE_VERSION
ARG OPENDKIM_VERSION
ARG OPENDKIM_UTILS_VERSION
ARG OPENDMARC_VERSION
ARG DUPLICITY_VERSION
ARG PY3_VIRTUALENV_VERSION
ARG LIBIDN2_VERSION
ARG IDN2_UTILS_VERSION
ARG CERTBOT_VERSION
ARG BIND_VERSION
ARG BIND_TOOLS_VERSION

ARG MAILINABOX_REPO_URL="https://github.com/mail-in-a-box/mailinabox.git"
ARG MAILINABOX_VERSION="v73"
# In container orchestration (e.g. Kubernetes), consider ingress-based protections instead of Fail2Ban.
ARG INSTALL_FAIL2BAN="false"
# In container orchestration (e.g. Kubernetes), or when you have infront nginx,
# you don't need local in-container Let's Encrypt. (set to false)
ARG WITH_SSL="true"
# In Kubernetes, SSL is handled by cert-manager via ingress, so WITH_SSL should be false
ARG IN_KUBERNETES="false"
ARG ENABLE_INTERNAL_BIND="false"

ARG STORAGE_USER="user-data"
ARG STORAGE_ROOT="/home/user-data"

ARG PRIVATE_IP="127.0.0.1"
ARG PRIVATE_IPV6=""
ARG DEFAULT_MTA_STS_MODE="enforce"

ARG DOVECOT_VERSION
ARG DOVECOT_BASE_VERSION
ARG PIGEONHOLE_VERSION

# If IN_KUBERNETES is true, automatically disable WITH_SSL (SSL handled by cert-manager)
# Compute final WITH_SSL value: if IN_KUBERNETES=true, force WITH_SSL=false
# Since ENV doesn't support conditionals, we compute it and override WITH_SSL ARG
RUN if [ "${IN_KUBERNETES}" = "true" ]; then \
        echo "IN_KUBERNETES=true detected, forcing WITH_SSL=false"; \
        # Override WITH_SSL for subsequent RUN commands by setting it in environment
        export WITH_SSL="false"; \
        echo "WITH_SSL=false" > /tmp/override_with_ssl; \
    else \
        echo "WITH_SSL=${WITH_SSL}" > /tmp/override_with_ssl; \
    fi

# Set environment variables
ENV INSTALL_FAIL2BAN=${INSTALL_FAIL2BAN} \
    STORAGE_USER=${STORAGE_USER} \
    STORAGE_ROOT=${STORAGE_ROOT} \
    PRIVATE_IP=${PRIVATE_IP} \
    PRIVATE_IPV6=${PRIVATE_IPV6} \
    DEFAULT_MTA_STS_MODE=${DEFAULT_MTA_STS_MODE} \
    ENABLE_INTERNAL_BIND=${ENABLE_INTERNAL_BIND} \
    MAILINABOX_VERSION=${MAILINABOX_VERSION} \
    IN_KUBERNETES=${IN_KUBERNETES}

# Set WITH_SSL from computed value
# Read the computed value and set it in environment files for runtime
# Keep the file for use in subsequent RUN commands
# hadolint ignore=DL4006
RUN FINAL_WITH_SSL=$(cat /tmp/override_with_ssl | cut -d'=' -f2) && \
    echo "WITH_SSL=${FINAL_WITH_SSL}" >> /etc/environment && \
    echo "export WITH_SSL=${FINAL_WITH_SSL}" >> /etc/profile.d/mailinabox.sh

# Set WITH_SSL in ENV
# For build-time, we use the original WITH_SSL value
# At runtime, it will be overridden by /etc/environment if IN_KUBERNETES=true
ENV WITH_SSL=${WITH_SSL}

# Install runtime dependencies and git for cloning
RUN apk add --no-cache \
        bash=${BASH_VERSION} \
        bc=${BC_VERSION} \
        build-base=${BUILD_BASE_VERSION} \
        ca-certificates=${CA_CERTIFICATES_VERSION} \
        chrony=${CHRONY_VERSION} \
        coreutils=${COREUTILS_VERSION} \
        curl=${CURL_VERSION} \
        dcron=${DCRON_VERSION} \
        file=${FILE_VERSION} \
        git=${GIT_VERSION} \
        linux-headers=${LINUX_HEADERS_VERSION} \
        musl-locales=${MUSL_LOCALES_VERSION} \
        musl-locales-lang=${MUSL_LOCALES_LANG_VERSION} \
        netcat-openbsd=${NETCAT_OPENBSD_VERSION} \
        openssh-client-default=${OPENSSH_CLIENT_VERSION} \
        postfix=${POSTFIX_VERSION} \
        postfix-sqlite=${POSTFIX_SQLITE_VERSION} \
        postfix-pcre=${POSTFIX_PCRE_VERSION} \
        python3=${PYTHON3_VERSION} \
        python3-dev=${PYTHON3_DEV_VERSION} \
        py3-pip=${PY3_PIP_VERSION} \
        py3-setuptools=${PY3_SETUPTOOLS_VERSION} \
        py3-wheel=${PY3_WHEEL_VERSION} \
        rsync=${RSYNC_VERSION} \
        rsyslog=${RSYSLOG_VERSION} \
        sudo=${SUDO_VERSION} \
        tar=${TAR_VERSION} \
        tzdata=${TZDATA_VERSION} \
        unzip=${UNZIP_VERSION} \
        wget=${WGET_VERSION} \
        xz=${XZ_VERSION}

#Install perl needed by postgrey
# Pin package versions for security (prevents supply chain attacks)
RUN apk add --no-cache \
        perl=${PERL_VERSION} \
        perl-dbi=${PERL_DBI_VERSION} \
        perl-dbd-sqlite=${PERL_DBD_SQLITE_VERSION} \
        perl-net-dns=${PERL_NET_DNS_VERSION} \
        perl-netaddr-ip=${PERL_NETADDR_IP_VERSION} \
        perl-ldap=${PERL_LDAP_VERSION} \
        perl-net-server=${PERL_NET_SERVER_VERSION} \
        perl-io-socket-ssl=${PERL_IO_SOCKET_SSL_VERSION} \
        perl-io-socket-inet6=${PERL_IO_SOCKET_INET6_VERSION} \
        perl-io-multiplex=${PERL_IO_MULTIPLEX_VERSION} \
        perl-crypt-ssleay=${PERL_CRYPT_SSLEAY_VERSION} \
        perl-mozilla-ca=${PERL_MOZILLA_CA_VERSION} \
        db=${DB_VERSION}

# Pin package versions for security (prevents supply chain attacks)
RUN apk add --no-cache \
        dovecot=${DOVECOT_VERSION} \
        dovecot-lmtpd=${DOVECOT_VERSION} \
        dovecot-sqlite=${DOVECOT_VERSION} \
        sqlite=${SQLITE_VERSION}
# Dovecot packages on alpine include imap, pop3
# sieve is manually built from source in pigeonhole-builder stage

# Pin package versions for security (prevents supply chain attacks)
RUN apk add --no-cache \
        opendkim=${OPENDKIM_VERSION} \
        opendkim-utils=${OPENDKIM_UTILS_VERSION} \
        opendmarc=${OPENDMARC_VERSION}
# opendkim-utils contains the opendkim-genkey command

# duplicity is used to make backups of user data.
# virtualenv is used to isolate the Python 3 packages we
# install via pip from the system-installed packages (can be removed as we are in a container).
# Pin package versions for security (prevents supply chain attacks)
RUN apk add --no-cache \
        duplicity=${DUPLICITY_VERSION} \
        py3-pip=${PY3_PIP_VERSION} \
        py3-virtualenv=${PY3_VIRTUALENV_VERSION} \
        rsync=${RSYNC_VERSION}

# Install libidn2 (library) and idn2-utils (provides idn2 command-line tool for IDN conversion)
# Pin package versions for security (prevents supply chain attacks)
RUN apk add --no-cache \
        libidn2=${LIBIDN2_VERSION} \
        idn2-utils=${IDN2_UTILS_VERSION}


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
# Create virtualenv for management daemon Python packages
RUN mkdir -p /usr/local/lib/mailinabox && \
    virtualenv -ppython3 /usr/local/lib/mailinabox/env

# Install Python packages in virtualenv
# Copy requirements file for version pinning (security: prevents supply chain attacks)
COPY requirements.txt /tmp/requirements.txt
RUN /usr/local/lib/mailinabox/env/bin/pip install --no-cache-dir -r /tmp/requirements.txt

# End of Mail-in-a-Box management daemon dependencies and pre-requisites
################################################################################

# Optional SSL tooling
# Read WITH_SSL from computed value if available, otherwise use original
# hadolint ignore=DL4006
RUN WITH_SSL_VALUE=$(cat /tmp/override_with_ssl 2>/dev/null | cut -d'=' -f2 || echo "${WITH_SSL}") && \
    if [ "${WITH_SSL_VALUE}" = "true" ]; then \
        apk add --no-cache openssl=${OPENSSL_VERSION} certbot=${CERTBOT_VERSION}; \
    fi

# Prepare workspace
WORKDIR /opt

# Clone the specified release tag
RUN git clone --depth 1 --branch "${MAILINABOX_VERSION}" "${MAILINABOX_REPO_URL}" MailInABox

COPY mailinabox-patch/management/*.py /opt/MailInABox/management/
COPY mailinabox-config/ /opt/mailinabox-config/
COPY install/ /opt/install/
COPY entrypoint/ /opt/entrypoint/
COPY install/functions.sh /opt/entrypoint/functions.sh
COPY s6/ /etc/
RUN chmod +x /opt/install/*.sh /opt/entrypoint/*.sh /etc/cont-init.d/* /etc/services.d/*/run && \
    find /etc/services.d -name finish -type f -exec chmod +x {} \;

ENV IN_A_DOCKER=true

# Optional internal recursive DNS resolver packages
RUN     if [ "${ENABLE_INTERNAL_BIND}" = "true" ]; then \
        apk add --no-cache bind=${BIND_VERSION} bind-tools=${BIND_TOOLS_VERSION}; \
        /bin/sh /opt/install/setup_bind.sh; \
    fi


WORKDIR /opt/MailInABox

# Prepare initial configuration
RUN /bin/sh /opt/install/prepare_conf.sh

# Optional Fail2Ban install & configuration
RUN /bin/sh /opt/install/setup_fail2ban.sh

# Generate default SSL assets (optional)
# Will be skipped if WITH_SSL is false.
# Read WITH_SSL from computed value if available
# hadolint ignore=DL4006
RUN WITH_SSL_VALUE=$(cat /tmp/override_with_ssl 2>/dev/null | cut -d'=' -f2 || echo "${WITH_SSL}") && \
    if [ "${WITH_SSL_VALUE}" = "true" ]; then \
        /bin/sh /opt/install/setup_ssl_base.sh; \
    fi

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

# Clean up temporary file after all uses
RUN rm -f /tmp/override_with_ssl

# Wait a maximum of 5 minutes for services to start
# It is needed because the SSL certificate generation can take several minutes:
# openssl dhparam -out "${STORAGE_ROOT}/ssl/dh2048.pem" 2048 can take several minutes
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=300000

ENTRYPOINT ["/init"]
CMD []
