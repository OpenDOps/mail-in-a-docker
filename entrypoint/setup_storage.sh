#!/bin/sh
set -eu

: "${STORAGE_USER:=user-data}"
: "${STORAGE_ROOT:=/home/user-data}"

echo "DEBUG: setup_storage.sh - STORAGE_USER=${STORAGE_USER}"
echo "DEBUG: setup_storage.sh - STORAGE_ROOT=${STORAGE_ROOT}"

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
