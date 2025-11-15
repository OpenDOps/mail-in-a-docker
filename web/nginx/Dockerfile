FROM alpine:3.20

ARG WITH_PHP="true"
ARG PHP_VER="8.2"
ARG STORAGE_ROOT="/home/user-data"

ENV PHP_VER=${PHP_VER} \
    STORAGE_ROOT=${STORAGE_ROOT} \
    WITH_PHP=${WITH_PHP}

#Requires PRIMARY_HOSTNAME environment variable

# Install nginx, PHP-FPM, and dependencies
RUN apk add --no-cache \
        nginx \
        curl \
        wget \
        unzip \
        netcat-openbsd \
        gettext

# Optional SSL tooling
# Alpine uses php82 instead of php8.2 for package names
# Some extensions are PECL packages (pecl-apcu, pecl-imagick)
RUN if [ "${WITH_PHP}" = "true" ]; then \
        PHP_PKG=$(echo "php${PHP_VER}" | tr -d '.'); \
        apk add --no-cache \
            ${PHP_PKG} \
            ${PHP_PKG}-fpm \
            ${PHP_PKG}-cli \
            ${PHP_PKG}-gd \
            ${PHP_PKG}-intl \
            ${PHP_PKG}-imap \
            ${PHP_PKG}-curl \
            ${PHP_PKG}-xml \
            ${PHP_PKG}-mbstring \
            ${PHP_PKG}-zip \
            ${PHP_PKG}-pecl-apcu \
            ${PHP_PKG}-pecl-imagick \
            ${PHP_PKG}-gmp \
            ${PHP_PKG}-bcmath \
            ${PHP_PKG}-sqlite3 \
            ${PHP_PKG}-soap; \
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

