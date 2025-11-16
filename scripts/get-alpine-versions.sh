#!/bin/bash
# Script to extract Alpine package versions for version pinning
# Usage: ./scripts/get-alpine-versions.sh <package1> <package2> ...

set -e

ALPINE_VERSION="${ALPINE_VERSION:-3.20}"

echo "# Alpine ${ALPINE_VERSION} package versions"
echo "# Generated on: $(date)"
echo ""

for pkg in "$@"; do
    echo -n "Getting version for $pkg... "
    VERSION=$(docker run --rm alpine:${ALPINE_VERSION} sh -c \
        "apk update >/dev/null 2>&1 && apk info $pkg 2>/dev/null | grep -E '^[a-z].*-[0-9]' | head -1" 2>/dev/null || echo "")
    if [ -n "$VERSION" ]; then
        echo "$VERSION"
        echo "$pkg=$VERSION"
    else
        echo "NOT FOUND"
        echo "# $pkg - VERSION NOT FOUND"
    fi
    echo ""
done
