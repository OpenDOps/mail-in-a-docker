#!/bin/sh
set -eu

LISTEN_IPV4="${BIND_LISTEN_ADDRESSES:-127.0.0.1}"
LISTEN_IPV6="${BIND_LISTEN_ADDRESSES_V6:-}"
ALLOW_RECURSION="${BIND_ALLOW_RECURSION:-any}"

format_list() {
    out=""
    for addr in "$@"; do
        [ -n "$addr" ] || continue
        if [ -n "$out" ]; then
            out="${out} ${addr};"
        else
            out="${addr};"
        fi
    done
    echo "${out:-none;}"
}

allow_block() {
    if [ "$1" = "any" ]; then
        echo "any;"
    else
        format_list "$@"
    fi
}

mkdir -p /etc/bind /var/bind /run/named

# Copy root hints from build-time location (downloaded in Dockerfile)
# The file is already in the image at /usr/share/dns/root.hints
if [ -f /usr/share/dns/root.hints ]; then
    cp /usr/share/dns/root.hints /var/bind/root.hint
elif [ -f /usr/share/dns/root.hint ]; then
    cp /usr/share/dns/root.hint /var/bind/root.hint
elif [ -f /var/bind/root.hint ]; then
    # Already exists, keep it
    echo "Using existing root.hint"
else
    # Fallback: create minimal root hints if somehow missing
    echo "Warning: Root hints not found, creating minimal version"
    cat > /var/bind/root.hint <<'ROOTHINT'
.                        3600000  IN  NS    A.ROOT-SERVERS.NET.
A.ROOT-SERVERS.NET.      3600000  A     198.41.0.4
A.ROOT-SERVERS.NET.      3600000  AAAA  2001:503:ba3e::2:30
ROOTHINT
fi

cat > /etc/bind/named.conf <<EOF
options {
    directory "/var/bind";
    pid-file "/run/named/named.pid";
    listen-on { $(format_list $LISTEN_IPV4) };
    listen-on-v6 { $(format_list ${LISTEN_IPV6:-}) };
    recursion yes;
    allow-query { $(allow_block $ALLOW_RECURSION) };
    allow-recursion { $(allow_block $ALLOW_RECURSION) };
    dnssec-validation auto;
    auth-nxdomain no;
    max-recursion-queries 100;
};

zone "." IN {
    type hint;
    file "root.hint";
};
EOF

chown -R named:named /etc/bind /var/bind /run/named
