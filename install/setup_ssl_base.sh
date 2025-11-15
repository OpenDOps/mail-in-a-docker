#!/bin/bash
set -euo pipefail

if [ "${WITH_SSL:-false}" != "true" ]; then
    exit 0
fi

cd /opt/MailInABox

source /opt/install/functions.sh
[ -f /etc/mailinabox.conf ] && source /etc/mailinabox.conf

# Create SSL cleanup script
SCRIPT_PATH=/usr/local/bin/mailinabox-ssl-cleanup
cat > "$SCRIPT_PATH" <<'EOF'
#!/bin/sh
cd /opt/MailInABox
./tools/ssl_cleanup
EOF
chmod +x "$SCRIPT_PATH"

# Add to dcron (daily at 4am)
CRON_TMP=$(mktemp)
grep -v 'mailinabox-ssl-cleanup' /etc/crontabs/root >"$CRON_TMP" 2>/dev/null || true
{
    cat "$CRON_TMP"
    echo "# Mail-in-a-Box SSL cleanup (daily at 4am)"
    echo "0 4 * * * $SCRIPT_PATH"
} > /etc/crontabs/root
rm -f "$CRON_TMP"