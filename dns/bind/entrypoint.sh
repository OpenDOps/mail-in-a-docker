#!/bin/sh
set -eu

: "${IN_KUBERNETES:=false}"
: "${BIND_LISTEN_ADDRESSES:=0.0.0.0}"
: "${BIND_LISTEN_ADDRESSES_V6:=}"
: "${BIND_ALLOW_RECURSION:=any}"
: "${BIND_UPSTREAM_RESOLVER:=}"

if [ "$IN_KUBERNETES" = "true" ]; then
    # Try to get kube-dns service cluster IP using Kubernetes API
    # Service account token and CA cert are automatically mounted in all pod containers
    TOKEN_FILE="/var/run/secrets/kubernetes.io/serviceaccount/token"
    CA_FILE="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
    # Use KUBERNETES_SERVICE_HOST environment variable (set by Kubernetes) instead of DNS
    # This works even when dnsPolicy: None
    KUBERNETES_SERVICE_HOST="${KUBERNETES_SERVICE_HOST:-}"
    KUBERNETES_SERVICE_PORT="${KUBERNETES_SERVICE_PORT:-443}"
    # Initialize KUBE_DNS_IP to avoid "parameter not set" error with set -u
    KUBE_DNS_IP=""
    if [ -z "$KUBERNETES_SERVICE_HOST" ]; then
        echo "DEBUG (dns/bind/entrypoint.sh): KUBERNETES_SERVICE_HOST not set, cannot use Kubernetes API"
    else
        API_SERVER="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"
        echo "DEBUG (dns/bind/entrypoint.sh): API_SERVER: $API_SERVER"

        if [ -f "$TOKEN_FILE" ] && [ -f "$CA_FILE" ]; then
            TOKEN=$(cat "$TOKEN_FILE" 2>/dev/null || echo "")
            if [ -n "$TOKEN" ]; then
                # Try kube-dns first using curl (more reliable than wget for API calls)
                RESPONSE=$(curl -sSf --cacert "$CA_FILE" -H "Authorization: Bearer $TOKEN" \
                    "${API_SERVER}/api/v1/namespaces/kube-system/services/kube-dns" 2>/dev/null || echo "")
                echo "DEBUG (dns/bind/entrypoint.sh): RESPONSE KUBE-DNS: $RESPONSE"
                if [ -n "$RESPONSE" ]; then
                    # Extract clusterIP from JSON response using grep and sed
                    KUBE_DNS_IP=$(echo "$RESPONSE" | grep -o '"clusterIP":"[^"]*"' | sed 's/"clusterIP":"\([^"]*\)"/\1/' | head -1)
                fi

                # Fallback to coredns if kube-dns not found or empty
                if [ -z "$KUBE_DNS_IP" ] || [ "$KUBE_DNS_IP" = "null" ] || [ "$KUBE_DNS_IP" = "None" ] || [ "$KUBE_DNS_IP" = "" ]; then
                    RESPONSE=$(curl -sSf --cacert "$CA_FILE" -H "Authorization: Bearer $TOKEN" \
                        "${API_SERVER}/api/v1/namespaces/kube-system/services/coredns" 2>/dev/null || echo "")
                    echo "DEBUG (dns/bind/entrypoint.sh): RESPONSE COREDNS: $RESPONSE"
                    if [ -n "$RESPONSE" ]; then
                        KUBE_DNS_IP=$(echo "$RESPONSE" | grep -o '"clusterIP":"[^"]*"' | sed 's/"clusterIP":"\([^"]*\)"/\1/' | head -1)
                    fi
                fi

                if [ -n "$KUBE_DNS_IP" ] && [ "$KUBE_DNS_IP" != "null" ] && [ "$KUBE_DNS_IP" != "None" ] && [ "$KUBE_DNS_IP" != "" ]; then
                    export BIND_UPSTREAM_RESOLVER="$KUBE_DNS_IP"
                    echo "DEBUG (dns/bind/entrypoint.sh): Using detected kube-dns/coredns service IP as upstream resolver: $KUBE_DNS_IP"
                else
                    echo "DEBUG (dns/bind/entrypoint.sh): Could not determine kube-dns/coredns IP from Kubernetes API, using default/fallback resolver"
                fi
            else
                echo "DEBUG (dns/bind/entrypoint.sh): Service account token not found, using default/fallback resolver"
            fi
        else
            echo "DEBUG (dns/bind/entrypoint.sh): Service account files not mounted, using default/fallback resolver"
        fi
    fi
fi


echo "DEBUG (dns/bind/entrypoint.sh): BIND_UPSTREAM_RESOLVER: $BIND_UPSTREAM_RESOLVER"

export BIND_LISTEN_ADDRESSES BIND_LISTEN_ADDRESSES_V6 BIND_ALLOW_RECURSION BIND_UPSTREAM_RESOLVER

echo "DEBUG (dns/bind/entrypoint.sh): BIND_UPSTREAM_RESOLVER: $BIND_UPSTREAM_RESOLVER"
echo "DEBUG (dns/bind/entrypoint.sh): BIND_LISTEN_ADDRESSES: $BIND_LISTEN_ADDRESSES"
echo "DEBUG (dns/bind/entrypoint.sh): BIND_LISTEN_ADDRESSES_V6: $BIND_LISTEN_ADDRESSES_V6"
echo "DEBUG (dns/bind/entrypoint.sh): BIND_ALLOW_RECURSION: $BIND_ALLOW_RECURSION"

# Copy to mounted directories
cp /etc/bind-tmp/* /etc/bind/

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
        awk -v ip="$BIND_UPSTREAM_RESOLVER" '/# UPSTREAM_RESOLVER_PLACEHOLDER/ {
            print "zone \"cluster.local\" {";
            print "    type forward;";
            print "    forward only;";
            print "    forwarders { " ip "; };";
            print "};";
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
rndc -k /etc/bind/rndc.key nta -lifetime 604800 cluster.local 2>&1 || echo "WARNING: Failed to set NTA for cluster.local"

# Stop background named and restart in foreground
echo "DEBUG (dns/bind/entrypoint.sh): Stopping background named and restarting in foreground"
rndc -k /etc/bind/rndc.key stop 2>&1 || kill $NAMED_PID 2>/dev/null || true
wait $NAMED_PID 2>/dev/null || true

# Set up cron job to refresh NTAs daily (at 2am)
echo "DEBUG (dns/bind/entrypoint.sh): Setting up cron job for NTA refresh"
mkdir -p /etc/crontabs /var/log
# Remove any existing refresh_nta.sh entries
grep -v 'refresh_nta.sh' /etc/crontabs/root > /tmp/cron.tmp 2>/dev/null || true
# Add daily NTA refresh job (at 2am)
{
    cat /tmp/cron.tmp 2>/dev/null || true
    echo "# Refresh BIND9 negative trust anchors daily (at 2am)"
    echo "0 2 * * * /usr/local/bin/refresh_nta.sh >> /var/log/nta-refresh.log 2>&1"
} > /etc/crontabs/root
rm -f /tmp/cron.tmp
chmod 600 /etc/crontabs/root

# Start cron daemon in background (will be inherited by PID 1 when we exec)
echo "DEBUG (dns/bind/entrypoint.sh): Starting cron daemon"
crond -f -S &

# Wait a moment for cron to start
sleep 1

# Now run named in foreground (this replaces the shell process)
# Cron will continue running as a background process (child of PID 1)
echo "DEBUG (dns/bind/entrypoint.sh): Starting named in foreground"
exec "$@" 2>&1
