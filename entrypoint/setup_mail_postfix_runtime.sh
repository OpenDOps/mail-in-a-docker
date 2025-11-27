#!/bin/bash
set -euo pipefail

cd /opt/MailInABox

source /opt/install/functions.sh
source /etc/mailinabox.conf

# Configure postgrey to use $STORAGE_ROOT/mail/postgrey/db for its database
# This must be done before creating the directory to ensure postgrey uses the correct path
tools/editconf.py /etc/default/postgrey \
	POSTGREY_OPTS=\""--inet=127.0.0.1:10023 --delay=180 --dbdir=$STORAGE_ROOT/mail/postgrey/db --user=postgrey --group=postgrey --whitelist-clients=/etc/postgrey/whitelist_clients --whitelist-recipients=/etc/postgrey/whitelist_recipients"\"

# Create postgrey database directory
mkdir -p "$STORAGE_ROOT/mail/postgrey/db"

# Clean up any stale Berkeley DB files that might prevent initialization
# Berkeley DB creates __db.* files and lock files that can cause "No space left on device" errors
# if they're corrupted or from a previous failed start
if [ -d "$STORAGE_ROOT/mail/postgrey/db" ]; then
    # Remove stale Berkeley DB files (but keep any valid database files if they exist)
    rm -f "$STORAGE_ROOT/mail/postgrey/db/__db."* 2>/dev/null || true
    rm -f "$STORAGE_ROOT/mail/postgrey/db/postgrey.lock" 2>/dev/null || true
    # Move any existing database files from old location
    if [ -d /var/lib/postgrey/db ] && [ "$(ls -A /var/lib/postgrey/db 2>/dev/null)" ]; then
        mv /var/lib/postgrey/db/* "$STORAGE_ROOT/mail/postgrey/db/" 2>/dev/null || true
    fi
fi

# Set correct ownership and permissions
if id postgrey >/dev/null 2>&1; then
    chown -R postgrey:postgrey "$STORAGE_ROOT/mail/postgrey/"
fi
chmod 700 "$STORAGE_ROOT/mail/postgrey/"{,db}

# Configure hostname and banner bindings that depend on runtime hostname/IP values.
tools/editconf.py /etc/postfix/main.cf \
	inet_interfaces=all \
	smtp_bind_address= \
	smtp_bind_address6= \
	myhostname="$PRIMARY_HOSTNAME" \
	smtpd_banner="\$myhostname ESMTP Hi, I'm a Mail-in-a-Pods (Alpine/Postfix; see https://github.com/OpenDOps/mail-in-a-docker/)" \
	mydestination=localhost \
	maillog_file=/var/log/mail.log \
	debug_peer_level=2 \
  smtp_tls_security_level=may \
  smtp_tls_CAfile=/etc/ssl/certs/ca-certificates.crt \
  virtual_transport=lmtp:[127.0.0.1]:10026

# Update outgoing mail header filters with runtime hostname/IP values.
sed -i "s/PRIMARY_HOSTNAME/$PRIMARY_HOSTNAME/" /etc/postfix/outgoing_mail_header_filters
sed -i "s/PUBLIC_IP/$PUBLIC_IP/" /etc/postfix/outgoing_mail_header_filters
