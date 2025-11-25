FROM nginx:alpine:3.20

# Set SHELL with pipefail for better error handling in RUN commands with pipes
SHELL ["/bin/sh", "-o", "pipefail", "-c"]

ARG WITH_PHP="true"
ARG PHP_VER="8.2"
ARG STORAGE_ROOT="/home/user-data"

ENV PHP_VER=${PHP_VER} \
    STORAGE_ROOT=${STORAGE_ROOT} \
# Pin PHP 8.2 package versions for security (prevents supply chain attacks)
ARG PHP82_VERSION="8.2.28-r0"
ARG PHP82_PECL_APCU_VERSION="5.1.23-r0"
ARG PHP82_PECL_IMAGICK_VERSION="3.7.0-r6"

ARG CURL_VERSION="8.14.1-r2"
ARG NETCAT_OPENBSD_VERSION="1.226-r0"
ARG GETTEXT_VERSION="0.22.5-r0"
ARG WGET_VERSION="1.24.5-r0"
ARG UNZIP_VERSION="6.0-r14"
ARG LIBIDN2_VERSION="2.3.7-r0"
ARG IDN2_UTILS_VERSION="2.3.7-r0"

ENV STORAGE_ROOT=${STORAGE_ROOT} \
    WITH_PHP=${WITH_PHP}

#Requires PRIMARY_HOSTNAME environment variable

# Install nginx, PHP-FPM, and dependencies
# Pin package versions for security (prevents supply chain attacks)
RUN apk add --no-cache \
        curl=${CURL_VERSION} \
        wget=${WGET_VERSION} \
        unzip=${UNZIP_VERSION} \
        netcat-openbsd=${NETCAT_OPENBSD_VERSION} \
        gettext=${GETTEXT_VERSION} \
        libidn2=${LIBIDN2_VERSION} \
        idn2-utils=${IDN2_UTILS_VERSION}

# Optional PHP 8.2 installation
# Pin package versions for security (prevents supply chain attacks)
# hadolint ignore=DL4006
RUN if [ "${WITH_PHP}" = "true" ]; then \
        PHP_PKG=$(echo "php${PHP_VER}" | tr -d '.'); \
        apk add --no-cache \
            "${PHP_PKG}=${PHP82_VERSION}" \
            "${PHP_PKG}-fpm=${PHP82_VERSION}" \
            "${PHP_PKG}-cli=${PHP82_VERSION}" \
            "${PHP_PKG}-gd=${PHP82_VERSION}" \
            "${PHP_PKG}-intl=${PHP82_VERSION}" \
            "${PHP_PKG}-imap=${PHP82_VERSION}" \
            "${PHP_PKG}-curl=${PHP82_VERSION}" \
            "${PHP_PKG}-xml=${PHP82_VERSION}" \
            "${PHP_PKG}-mbstring=${PHP82_VERSION}" \
            "${PHP_PKG}-zip=${PHP82_VERSION}" \
            "${PHP_PKG}-pecl-apcu=${PHP82_PECL_APCU_VERSION}" \
            "${PHP_PKG}-pecl-imagick=${PHP82_PECL_IMAGICK_VERSION}" \
            "${PHP_PKG}-gmp=${PHP82_VERSION}" \
            "${PHP_PKG}-bcmath=${PHP82_VERSION}" \
            "${PHP_PKG}-sqlite3=${PHP82_VERSION}" \
            "${PHP_PKG}-soap=${PHP82_VERSION}"; \
    fi

# Install s6-overlay for process supervision
ARG S6_OVERLAY_VERSION="v3.1.5.0"
ARG S6_ARCH="x86_64"
ADD https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp/
ADD https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz /tmp/
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-${S6_ARCH}.tar.xz && \
    rm /tmp/s6-overlay-*.tar.xz

# Copy setup scripts and configuration
COPY web/nginx/setup/ /opt/setup/
COPY web/nginx/s6/ /etc/
RUN chmod +x /opt/setup/*.sh && \
    find /etc/cont-init.d -type f -exec chmod +x {} \; && \
    find /etc/services.d -name run -type f -exec chmod +x {} \;

# Download jQuery and Bootstrap assets with checksum verification
# hadolint ignore=DL4006
RUN mkdir -p /usr/local/lib/mailinabox/vendor/assets && \
    wget --progress=dot:giga -O /usr/local/lib/mailinabox/vendor/assets/jquery.min.js \
        https://code.jquery.com/jquery-2.2.4.min.js && \
    echo "69bb69e25ca7d5ef0935317584e6153f3fd9a88c  /usr/local/lib/mailinabox/vendor/assets/jquery.min.js" | sha1sum -c --strict - && \
    wget --progress=dot:giga -O /tmp/bootstrap.zip \
        https://github.com/twbs/bootstrap/releases/download/v3.4.1/bootstrap-3.4.1-dist.zip && \
    echo "0bb64c67c2552014d48ab4db81c2e8c01781f580  /tmp/bootstrap.zip" | sha1sum -c --strict - && \
    unzip -q /tmp/bootstrap.zip -d /usr/local/lib/mailinabox/vendor/assets && \
    mv /usr/local/lib/mailinabox/vendor/assets/bootstrap-3.4.1-dist /usr/local/lib/mailinabox/vendor/assets/bootstrap && \
    rm -f /tmp/bootstrap.zip


COPY mailinabox-assets/ /opt/mailinabox-assets/

# Create directory for generated files
RUN mkdir -p /var/lib/mailinabox

# Set default environment variables if not provided
ENV MTA_STS_MODE=enforce

# Run nginx setup
RUN /bin/sh /opt/setup/setup_nginx.sh

# Remove default nginx site and sites-enabled/sites-available directories
# As we are using conf.d/local.conf
RUN rm -f /etc/nginx/http.d/default.conf
RUN rm -rf /etc/nginx/sites-enabled/
RUN rm -rf /etc/nginx/sites-available/

WORKDIR /opt

ENTRYPOINT ["/init"]
CMD []
