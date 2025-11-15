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
cp /usr/share/dns/root.hints /var/bind/root.hint

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
