#!/bin/sh
set -eu

: "${BIND_LISTEN_ADDRESSES:=0.0.0.0}"
: "${BIND_LISTEN_ADDRESSES_V6:=}"
: "${BIND_ALLOW_RECURSION:=any}"

export BIND_LISTEN_ADDRESSES BIND_LISTEN_ADDRESSES_V6 BIND_ALLOW_RECURSION

/bin/sh /opt/install/setup_bind.sh

exec "$@"

