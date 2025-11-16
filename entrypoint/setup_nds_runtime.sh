#!/bin/bash

source /opt/install/functions.sh
source /etc/mailinabox.conf

mkdir -p "${STORAGE_ROOT}/dns/dnssec"

FIRST=1
for algo in ${DNSSEC_ALGORITHMS}; do
    if [ ! -f "${STORAGE_ROOT}/dns/dnssec/${algo}.conf" ]; then
        if [ "${FIRST}" -eq 1 ]; then
            echo "Generating DNSSEC signing keys..."
            FIRST=0
        fi
        KSK=$(umask 077; cd "${STORAGE_ROOT}/dns/dnssec" || exit; ldns-keygen -r /dev/urandom -a "${algo}" -k _domain_)
        ZSK=$(umask 077; cd "${STORAGE_ROOT}/dns/dnssec" || exit; ldns-keygen -r /dev/urandom -a "${algo}" _domain_)
        cat > "${STORAGE_ROOT}/dns/dnssec/${algo}.conf" <<EOF
KSK=${KSK}
ZSK=${ZSK}
EOF
    fi
done

chown -R nsd:nsd "${STORAGE_ROOT}/dns"
