ARG GCC_VERSION=14.2.0-r6
ARG GPP_VERSION=14.2.0-r6
ARG MAKE_VERSION=4.4.1-r3
ARG LIBC_VERSION=1.2.5-r10
ARG LINUX_HEADERS_VERSION=6.14.2-r0
ARG OPENSSL_VERSION=3.5.4-r0
ARG LIBXML2_VERSION=2.13.9-r0
ARG JSON_C_VERSION=0.18-r1
ARG LIBUV_VERSION=1.51.0-r0
ARG ZLIB_VERSION=1.3.1-r2
ARG PROTOBUF_C_VERSION=1.5.2-r0
ARG FSTRM_VERSION=0.6.1-r4
ARG LIBCAP_VERSION=2.76-r0
ARG USERSPACE_RCU_VERSION=0.15.2-r0
ARG NGHTTP2_VERSION=1.65.0-r0
ARG KRB5_VERSION=1.21.3-r0
ARG PERL_VERSION=5.40.3-r0
ARG PYTHON3_VERSION=3.12.12-r0
ARG PY3_PIP_VERSION=25.1.1-r0
ARG WGET_VERSION=1.25.0-r1
ARG TAR_VERSION=1.35-r3
ARG BASH_VERSION=5.2.37-r0
ARG PKGCONF_VERSION=2.4.3-r0
ARG SHADOW_VERSION=4.17.3-r0

FROM alpine:3.22 AS builder

ARG BIND_VERSION=9.20.16
ARG BIND_URL=https://downloads.isc.org/isc/bind9/${BIND_VERSION}/bind-${BIND_VERSION}.tar.xz

ARG GCC_VERSION
ARG GPP_VERSION
ARG MAKE_VERSION
ARG LIBC_VERSION
ARG LINUX_HEADERS_VERSION
ARG OPENSSL_VERSION
ARG LIBXML2_VERSION
ARG JSON_C_VERSION
ARG LIBUV_VERSION
ARG ZLIB_VERSION
ARG PROTOBUF_C_VERSION
ARG FSTRM_VERSION
ARG LIBCAP_VERSION
ARG USERSPACE_RCU_VERSION
ARG NGHTTP2_VERSION
ARG KRB5_VERSION
ARG PERL_VERSION
ARG PYTHON3_VERSION
ARG PY3_PIP_VERSION
ARG WGET_VERSION
ARG TAR_VERSION
ARG BASH_VERSION
ARG SHADOW_VERSION

# Install build dependencies (using latest available versions in Alpine 3.22)
RUN apk add --no-cache \
    gcc=${GCC_VERSION} \
    g++=${GPP_VERSION} \
    make=${MAKE_VERSION} \
    libc-dev=${LIBC_VERSION} \
    linux-headers=${LINUX_HEADERS_VERSION} \
    openssl-dev=${OPENSSL_VERSION} \
    libxml2-dev=${LIBXML2_VERSION} \
    json-c-dev=${JSON_C_VERSION} \
    libuv-dev=${LIBUV_VERSION} \
    zlib-dev=${ZLIB_VERSION} \
    protobuf-c-dev=${PROTOBUF_C_VERSION} \
    fstrm-dev=${FSTRM_VERSION} \
    libcap-dev=${LIBCAP_VERSION} \
    userspace-rcu-dev=${USERSPACE_RCU_VERSION} \
    nghttp2-dev=${NGHTTP2_VERSION} \
    krb5-dev=${KRB5_VERSION} \
    perl=${PERL_VERSION} \
    python3=${PYTHON3_VERSION} \
    py3-pip=${PY3_PIP_VERSION} \
    wget=${WGET_VERSION} \
    tar=${TAR_VERSION} \
    bash=${BASH_VERSION} \
    shadow=${SHADOW_VERSION} \
    pkgconfig

# Download and extract BIND source
WORKDIR /tmp
RUN wget -q ${BIND_URL} && \
    tar -xf bind-${BIND_VERSION}.tar.xz && \
    cd bind-${BIND_VERSION} && \
    ./configure \
        --prefix=/usr \
        --sysconfdir=/etc/bind \
        --localstatedir=/var \
        --mandir=/usr/share/man \
        --infodir=/usr/share/info \
        --with-gssapi=yes \
        --with-libxml2 \
        --with-json-c \
        --with-openssl \
        --enable-dnstap \
        --enable-largefile \
        --enable-linux-caps \
        --enable-shared \
        --disable-static \
        --enable-plugins \
        CFLAGS="-Os -fstack-clash-protection -Wformat -Werror=format-security -fno-plt -g -D_GNU_SOURCE" \
        LDFLAGS="-Wl,--as-needed,-O1,--sort-common -Wl,-z,pack-relative-relocs" && \
    make -j$(nproc) && \
    make install DESTDIR=/tmp/bind-install

# Runtime stage
FROM alpine:3.22

# Redefine ARG variables for runtime stage (ARGs are scoped per stage)
ARG BASH_VERSION
ARG LIBXML2_VERSION
ARG JSON_C_VERSION
ARG LIBUV_VERSION
ARG ZLIB_VERSION
ARG PROTOBUF_C_VERSION
ARG FSTRM_VERSION
ARG LIBCAP_VERSION
ARG OPENSSL_VERSION
ARG USERSPACE_RCU_VERSION
ARG NGHTTP2_VERSION
ARG WGET_VERSION
ARG KRB5_VERSION
ARG SHADOW_VERSION

ARG CURL_VERSION=8.14.1-r2
ARG JQ_VERSION=1.8.1-r0
ARG DCRON_VERSION=4.6-r0
ARG COREUTILS_VERSION=9.7-r1
ARG TZDATA_VERSION=2025b-r0

# Install runtime dependencies (using latest available versions in Alpine 3.22)
RUN apk add --no-cache \
    bash=${BASH_VERSION} \
    libxml2=${LIBXML2_VERSION} \
    json-c=${JSON_C_VERSION} \
    libuv=${LIBUV_VERSION} \
    zlib=${ZLIB_VERSION} \
    protobuf-c=${PROTOBUF_C_VERSION} \
    fstrm=${FSTRM_VERSION} \
    libcap=${LIBCAP_VERSION} \
    openssl=${OPENSSL_VERSION} \
    userspace-rcu=${USERSPACE_RCU_VERSION} \
    nghttp2=${NGHTTP2_VERSION} \
    krb5=${KRB5_VERSION} \
    coreutils=${COREUTILS_VERSION} \
    tzdata=${TZDATA_VERSION} \
    wget=${WGET_VERSION} \
    curl=${CURL_VERSION} \
    jq=${JQ_VERSION} \
    dcron=${DCRON_VERSION} \
    shadow=${SHADOW_VERSION}

# Create named user and group (required by BIND)
RUN groupadd -r named && useradd -r -g named -d /var/bind -s /bin/false named

# Copy BIND from builder
# Note: BIND's make install only installs to /usr, not /etc
# We create /etc/bind ourselves in the runtime stage
COPY --from=builder /tmp/bind-install/usr /usr

# Create necessary directories
RUN mkdir -p /var/bind /run/named /etc/bind

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
