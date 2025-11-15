#!/bin/sh
set -eu

: "${STORAGE_USER:=user-data}"
: "${STORAGE_ROOT:=/home/user-data}"
: "${PRIVATE_IP:=127.0.0.1}"
: "${PRIVATE_IPV6:=}"

echo "DEBUG: setup_storage.sh - STORAGE_USER=${STORAGE_USER}"
echo "DEBUG: setup_storage.sh - STORAGE_ROOT=${STORAGE_ROOT}"
echo "DEBUG: setup_storage.sh - PRIVATE_IP=${PRIVATE_IP}"
echo "DEBUG: setup_storage.sh - PRIVATE_IPV6=${PRIVATE_IPV6}"
echo "DEBUG: setup_storage.sh - WITH_SSL=${WITH_SSL}"

if ! id -u "${STORAGE_USER}" >/dev/null 2>&1; then
    adduser -D -h "${STORAGE_ROOT}" "${STORAGE_USER}"
fi

mkdir -p "${STORAGE_ROOT}"
f="${STORAGE_ROOT}"
while [ "${f}" != "/" ]; do
    chmod a+rx "${f}"
    f=$(dirname "${f}")
done

cd /opt/MailInABox
chown -R "${STORAGE_USER}:${STORAGE_USER}" "${STORAGE_ROOT}"
