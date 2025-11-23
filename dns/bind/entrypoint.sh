#!/bin/sh
set -eu

: "${BIND_LISTEN_ADDRESSES:=0.0.0.0}"
: "${BIND_LISTEN_ADDRESSES_V6:=}"
: "${BIND_ALLOW_RECURSION:=any}"
: "${BIND_UPSTREAM_RESOLVER:=}"
: "${KUBE_DNS_IP_FILE:=}"

# If KUBE_DNS_IP_FILE is set and BIND_UPSTREAM_RESOLVER is a hostname, resolve it to IP
if [ -n "$KUBE_DNS_IP_FILE" ] && [ -f "$KUBE_DNS_IP_FILE" ]; then
    RESOLVED_IP=$(cat "$KUBE_DNS_IP_FILE" 2>/dev/null || echo "")
    if [ -n "$RESOLVED_IP" ]; then
        export BIND_UPSTREAM_RESOLVER="$RESOLVED_IP"
    fi
fi

# If BIND_UPSTREAM_RESOLVER is still a hostname, try to resolve it
if [ -n "$BIND_UPSTREAM_RESOLVER" ] && ! echo "$BIND_UPSTREAM_RESOLVER" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
    RESOLVED_IP=$(getent hosts "$BIND_UPSTREAM_RESOLVER" | awk '{print $1}' | head -1)
    if [ -n "$RESOLVED_IP" ]; then
        export BIND_UPSTREAM_RESOLVER="$RESOLVED_IP"
    fi
fi

export BIND_LISTEN_ADDRESSES BIND_LISTEN_ADDRESSES_V6 BIND_ALLOW_RECURSION BIND_UPSTREAM_RESOLVER

echo "DEBUG (dns/bind/entrypoint.sh): BIND_UPSTREAM_RESOLVER: $BIND_UPSTREAM_RESOLVER"
echo "DEBUG (dns/bind/entrypoint.sh): BIND_LISTEN_ADDRESSES: $BIND_LISTEN_ADDRESSES"
echo "DEBUG (dns/bind/entrypoint.sh): BIND_LISTEN_ADDRESSES_V6: $BIND_LISTEN_ADDRESSES_V6"
echo "DEBUG (dns/bind/entrypoint.sh): BIND_ALLOW_RECURSION: $BIND_ALLOW_RECURSION"

# Check if ConfigMap template is mounted
# This is used for Kubernetes Mail-in-a-Pods deployment
if [ -f /tmp/named.conf.template ]; then
    echo "DEBUG (dns/bind/entrypoint.sh): ConfigMap template found, processing it"
    # Ensure directories exist
    mkdir -p /var/bind /run/named /etc/bind

    # Try to find root hints in common locations, or use existing
    if [ ! -f /var/bind/root.hint ]; then
        if [ -f /usr/share/dns/root.hints ]; then
            cp /usr/share/dns/root.hints /var/bind/root.hint
        elif [ -f /usr/share/dns/root.hint ]; then
            cp /usr/share/dns/root.hint /var/bind/root.hint
        else
            echo "DEBUG (dns/bind/entrypoint.sh): Root hints not found, will be created by setup_bind.sh if needed"
        fi
    fi

    # Process the template: replace ALL occurrences of UPSTREAM_RESOLVER_PLACEHOLDER with resolved IP
    # Write to /etc/bind/named.conf (which is mounted as emptyDir, so it's writable)
    if [ -n "$BIND_UPSTREAM_RESOLVER" ] && echo "$BIND_UPSTREAM_RESOLVER" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        # BIND_UPSTREAM_RESOLVER is an IP, use it
        # This awk command replaces ALL lines containing UPSTREAM_RESOLVER_PLACEHOLDER
        # Indentation matches the template (8 spaces for zone blocks)
        awk -v ip="$BIND_UPSTREAM_RESOLVER" '/UPSTREAM_RESOLVER_PLACEHOLDER/ {
            print "    forwarders { " ip "; };"
            next
        } { print }' /tmp/named.conf.template > /etc/bind/named.conf
    else
        # No upstream resolver or not resolved, remove ALL placeholder lines
        sed '/# UPSTREAM_RESOLVER_PLACEHOLDER/d' /tmp/named.conf.template > /etc/bind/named.conf
    fi

    # Ensure the generated file is writable and has correct ownership
    chmod 644 /etc/bind/named.conf
    chown named:named /etc/bind/named.conf 2>/dev/null || true
    chown -R named:named /var/bind /run/named /etc/bind 2>/dev/null || true
    echo "DEBUG (dns/bind/entrypoint.sh): Generated /etc/bind/named.conf from ConfigMap template"
else
    echo "DEBUG (dns/bind/entrypoint.sh): No ConfigMap template found, running setup_bind.sh"
    # Fallback: generate named.conf using setup_bind.sh (for non-Kubernetes deployments)
    /bin/sh /opt/install/setup_bind.sh
fi

# Validate named.conf exists before starting
if [ ! -f /etc/bind/named.conf ]; then
    echo "ERROR (dns/bind/entrypoint.sh): /etc/bind/named.conf does not exist!"
    echo "DEBUG (dns/bind/entrypoint.sh): Listing /etc/bind"
    ls -la /etc/bind || true
    echo "DEBUG (dns/bind/entrypoint.sh): Listing /var/bind"
    ls -la /var/bind || true
    exit 1
fi

# Validate named.conf syntax before starting
echo "DEBUG (dns/bind/entrypoint.sh): Validating named.conf syntax"
if ! named-checkconf -z /etc/bind/named.conf 2>&1; then
    echo "ERROR (dns/bind/entrypoint.sh): named.conf validation failed!"
    echo "DEBUG (dns/bind/entrypoint.sh): named.conf contents:"
    cat /etc/bind/named.conf
    exit 1
fi
echo "DEBUG (dns/bind/entrypoint.sh): named.conf validation passed"

echo "DEBUG (dns/bind/entrypoint.sh): Final named.conf contents:"
cat /etc/bind/named.conf

echo "DEBUG (dns/bind/entrypoint.sh): ls -la /etc/bind:"
ls -la /etc/bind

# Start named in background to set up negative trust anchors
echo "DEBUG (dns/bind/entrypoint.sh): Starting named in background to configure NTAs"
"$@" > /tmp/named.log 2>&1 &
NAMED_PID=$!

# Wait for named to be ready (check if rndc responds)
echo "DEBUG (dns/bind/entrypoint.sh): Waiting for named to start..."
for i in $(seq 1 30); do
    if rndc -k /etc/bind/rndc.key status >/dev/null 2>&1; then
        echo "DEBUG (dns/bind/entrypoint.sh): named is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR (dns/bind/entrypoint.sh): named failed to start within 30 seconds"
        cat /tmp/named.log
        kill $NAMED_PID 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

# Set negative trust anchors for .local zones (disable DNSSEC validation)
echo "DEBUG (dns/bind/entrypoint.sh): Setting negative trust anchors for .local zones"
rndc -k /etc/bind/rndc.key nta local 604800 2>&1 || echo "WARNING: Failed to set NTA for local"
rndc -k /etc/bind/rndc.key nta cluster.local 604800 2>&1 || echo "WARNING: Failed to set NTA for cluster.local"
rndc -k /etc/bind/rndc.key nta svc.cluster.local 604800 2>&1 || echo "WARNING: Failed to set NTA for svc.cluster.local"

# Stop background named and restart in foreground
echo "DEBUG (dns/bind/entrypoint.sh): Stopping background named and restarting in foreground"
rndc -k /etc/bind/rndc.key stop 2>&1 || kill $NAMED_PID 2>/dev/null || true
wait $NAMED_PID 2>/dev/null || true

# Now run named in foreground (this replaces the shell process)
echo "DEBUG (dns/bind/entrypoint.sh): Starting named in foreground"
exec "$@" 2>&1
