#!/bin/sh
# Refresh BIND9 negative trust anchors for cluster.local zones
# NTAs expire after 7 days (604800 seconds), so we refresh them daily
# This script runs from the mailinabox container and connects to bind9 sidecar

set -eu

# Check if bind9 sidecar is enabled
if [ "${BIND_SIDECAR_ENABLED:-false}" != "true" ]; then
    echo "BIND_SIDECAR_ENABLED is not true, skipping NTA refresh"
    exit 0
fi

# Check if rndc.key exists (mounted from bind9 container or shared volume)
RNDC_KEY="/etc/bind/rndc.key"
if [ ! -f "$RNDC_KEY" ]; then
    # Try alternative location (if mounted differently)
    RNDC_KEY="/shared/rndc.key"
    if [ ! -f "$RNDC_KEY" ]; then
        echo "WARNING: rndc.key not found, cannot refresh NTAs"
        exit 0
    fi
fi

# Refresh negative trust anchors for cluster.local (7 days = 604800 seconds)
# cluster.local covers all subdomains (svc.cluster.local, etc.)
echo "Refreshing BIND9 negative trust anchors for cluster.local..."
rndc -k "$RNDC_KEY" -s 127.0.0.1 -p 953 nta -lifetime 604800 cluster.local 2>&1 || {
    echo "WARNING: Failed to refresh NTA for cluster.local"
    exit 0
}

echo "Successfully refreshed BIND9 negative trust anchors"
