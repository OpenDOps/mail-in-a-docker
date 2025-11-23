#!/bin/sh
# Refresh BIND9 negative trust anchors for cluster.local zones
# NTAs expire after 7 days (604800 seconds), so we refresh them daily
# This script runs inside the bind9 container

set -eu

# Check if rndc.key exists
RNDC_KEY="/etc/bind/rndc.key"
if [ ! -f "$RNDC_KEY" ]; then
    echo "WARNING: rndc.key not found at $RNDC_KEY, cannot refresh NTAs"
    exit 0
fi

# Check if named is running and rndc is accessible
if ! rndc -k "$RNDC_KEY" status >/dev/null 2>&1; then
    echo "WARNING: Cannot connect to named via rndc, skipping NTA refresh"
    exit 0
fi

# Refresh negative trust anchors for cluster.local (7 days = 604800 seconds)
# cluster.local covers all subdomains (svc.cluster.local, etc.)
echo "$(date): Refreshing BIND9 negative trust anchors for cluster.local..."
rndc -k "$RNDC_KEY" nta -lifetime 604800 cluster.local 2>&1 || {
    echo "WARNING: Failed to refresh NTA for cluster.local"
    exit 0
}

echo "$(date): Successfully refreshed BIND9 negative trust anchors for cluster.local"
