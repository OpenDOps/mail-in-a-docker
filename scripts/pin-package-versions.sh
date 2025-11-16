#!/bin/bash
# Script to extract and pin Alpine package versions
# This helps maintain security by pinning exact versions

set -e

ALPINE_VERSION="${ALPINE_VERSION:-3.20}"
# Treat the arguments as an array to avoid SC2124/SC2128.
PACKAGES=("$@")

if [ "${#PACKAGES[@]}" -eq 0 ]; then
    echo "Usage: $0 <package1> <package2> ..."
    echo "Example: $0 bash curl nginx"
    exit 1
fi

echo "# Extracting package versions from Alpine ${ALPINE_VERSION}"
echo ""

for pkg in "${PACKAGES[@]}"; do
    VERSION=$(docker run --rm alpine:${ALPINE_VERSION} sh -c \
        "apk update >/dev/null 2>&1 && apk info $pkg 2>/dev/null | grep -E '^[a-z].*-[0-9]' | head -1 | sed 's/ .*//'" 2>/dev/null || echo "")
    if [ -n "$VERSION" ]; then
        echo "$pkg=$VERSION"
    else
        echo "# $pkg - VERSION NOT FOUND" >&2
    fi
done
