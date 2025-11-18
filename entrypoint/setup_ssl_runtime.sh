#!/bin/bash

source /opt/install/functions.sh
source /etc/mailinabox.conf

echo "DEBUG: setup_ssl_runtime.sh - WITH_SSL=${WITH_SSL}"

mkdir -p "${STORAGE_ROOT}/ssl"

echo "DEBUG: Listing files in /etc/ssl/certs/"
ls -l /etc/ssl/certs/
echo "DEBUG: Listing files in /etc/ssl/private/"
ls -l /etc/ssl/private/

if [ -f "/etc/ssl/private/tls-0.key" ]; then
    echo "DEBUG: /etc/ssl/private/tls-0.key exist"
else
    echo "DEBUG: /etc/ssl/private/tls-0.key do NOT exist"
fi
if [ -f "/etc/ssl/certs/tls-0.crt" ]; then
    echo "DEBUG: /etc/ssl/certs/tls-0.crt exist"
else
    echo "DEBUG: /etc/ssl/certs/tls-0.crt do NOT exist"
fi


if [ -f "/etc/ssl/certs/tls-0.crt" ] && [ -f "/etc/ssl/private/tls-0.key" ]; then
    echo "DEBUG: Found cert-manager TLS secret, syncing to ${STORAGE_ROOT}/ssl"
    cp /etc/ssl/certs/tls.crt "${STORAGE_ROOT}/ssl/ssl_certificate.pem"
    cp /etc/ssl/private/tls.key "${STORAGE_ROOT}/ssl/ssl_private_key.pem"
    chmod 600 "${STORAGE_ROOT}/ssl/ssl_certificate.pem" "${STORAGE_ROOT}/ssl/ssl_private_key.pem"
fi

if [ "${WITH_SSL:-false}" == "true" ]; then
    : "${STORAGE_ROOT:=/home/user-data}"
    : "${PRIMARY_HOSTNAME:=box.example.com}"

    if [ ! -x /usr/bin/openssl ]; then
        echo "openssl binary not found; cannot generate default TLS assets."
        exit 1
    fi

    if [ ! -f "${STORAGE_ROOT}/ssl/ssl_private_key.pem" ]; then
        (umask 077; hide_output \
            openssl genrsa -out "${STORAGE_ROOT}/ssl/ssl_private_key.pem" 2048)
    fi

    echo "DEBUG: setup_ssl_runtime.sh - Checking certificate for PRIMARY_HOSTNAME=${PRIMARY_HOSTNAME}"
    if [ ! -f "${STORAGE_ROOT}/ssl/ssl_certificate.pem" ]; then
        echo "DEBUG: setup_ssl_runtime.sh - No certificate found, generating self-signed certificate"
        CSR=$(mktemp /tmp/ssl_cert_sign_req.XXXXXX)
        hide_output \
            openssl req -new -key "${STORAGE_ROOT}/ssl/ssl_private_key.pem" -out "${CSR}" \
            -sha256 -subj "/CN=${PRIMARY_HOSTNAME}"

        CERT="${STORAGE_ROOT}/ssl/${PRIMARY_HOSTNAME}-selfsigned-$(date --rfc-3339=date | tr -d -).pem"
        hide_output \
            openssl x509 -req -days 365 \
                -in "${CSR}" -signkey "${STORAGE_ROOT}/ssl/ssl_private_key.pem" -out "${CERT}"
        rm -f "${CSR}"
        ln -sf "${CERT}" "${STORAGE_ROOT}/ssl/ssl_certificate.pem"

        echo "DEBUG: setup_ssl_runtime.sh - Certificate generated"
    fi
fi

if [ ! -f "${STORAGE_ROOT}/ssl/dh2048.pem" ]; then
    echo "DEBUG: setup_ssl_runtime.sh - DH parameters generation started"
    hide_output openssl dhparam -out "${STORAGE_ROOT}/ssl/dh2048.pem" 2048
fi

echo "DEBUG: setup_ssl_runtime.sh - certificate and DH parameters generated"
