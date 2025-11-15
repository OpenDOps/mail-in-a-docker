#!/bin/sh
set -eu

: "${STORAGE_USER:=user-data}"
: "${STORAGE_ROOT:=/home/user-data}"
: "${PRIVATE_IP:=127.0.0.1}"
: "${PRIVATE_IPV6:=}"
: "${IN_A_DOCKER:=false}"
: "${WITH_SSL:=false}"
: "${IN_KUBERNETES:=false}"

cat > /etc/mailinabox.conf <<EOF
STORAGE_USER=${STORAGE_USER}
STORAGE_ROOT=${STORAGE_ROOT}
PRIVATE_IP=${PRIVATE_IP}
PRIVATE_IPV6=${PRIVATE_IPV6}
IN_A_DOCKER=${IN_A_DOCKER}
WITH_SSL=${WITH_SSL}
IN_KUBERNETES=${IN_KUBERNETES}
EOF

