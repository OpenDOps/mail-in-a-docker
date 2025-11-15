#!/bin/bash
set -euo pipefail

cd /opt/MailInABox

source /opt/install/functions.sh
[ -f /etc/mailinabox.conf ] && source /etc/mailinabox.conf

export DISABLE_FIREWALL=1


if addgroup --help 2>&1 | grep -q '\-S'; then
    addgroup -S postgrey 2>/dev/null || true
else
    addgroup --system postgrey 2>/dev/null || true
fi

if adduser --help 2>&1 | grep -q '\-S'; then
    adduser -S -D -H -G postgrey postgrey 2>/dev/null || true
else
    adduser --system --no-create-home --group postgrey 2>/dev/null || true
fi


mkdir -p /etc/default /etc/postgrey /var/lib/postgrey
cat >/etc/default/postgrey <<'EOF'
# Mail-in-a-Box default Postgrey options
POSTGREY_OPTS="--inet=127.0.0.1:10023 --delay=180 --dbdir=/var/lib/postgrey/db --user=postgrey --group=postgrey --whitelist-clients=/etc/postgrey/whitelist_clients --whitelist-recipients=/etc/postgrey/whitelist_recipients"
EOF
touch /etc/postgrey/whitelist_clients
touch /etc/postgrey/whitelist_recipients

if ! command -v postgrey >/dev/null 2>&1; then
    echo "postgrey executable not found; ensure the build stage copied it correctly." >&2
    exit 1
fi

# Queue and SMTP smuggling related defaults that do not depend on PUBLIC_IP/PRIMARY_HOSTNAME.
tools/editconf.py /etc/postfix/main.cf \
	delay_warning_time=3h \
	maximal_queue_lifetime=2d \
	bounce_queue_lifetime=1d

tools/editconf.py /etc/postfix/main.cf -e \
       smtpd_data_restrictions= \
       smtpd_discard_ehlo_keywords=

tools/editconf.py /etc/postfix/main.cf \
       smtpd_forbid_bare_newline=normalize

# Configure submission services and cleanup helpers (no PUBLIC_IP/PRIMARY_HOSTNAME dependencies).
tools/editconf.py /etc/postfix/master.cf -s -w \
	"smtps=inet n       -       -       -       -       smtpd
	  -o smtpd_tls_wrappermode=yes
	  -o smtpd_sasl_auth_enable=yes
	  -o syslog_name=postfix/submission
	  -o smtpd_milters=inet:127.0.0.1:8891
	  -o cleanup_service_name=authclean" \
	"submission=inet n       -       -       -       -       smtpd
	  -o smtpd_sasl_auth_enable=yes
	  -o syslog_name=postfix/submission
	  -o smtpd_milters=inet:127.0.0.1:8891
	  -o smtpd_tls_security_level=encrypt
	  -o cleanup_service_name=authclean" \
	"authclean=unix  n       -       -       -       0       cleanup
	  -o header_checks=pcre:/etc/postfix/outgoing_mail_header_filters
	  -o nested_header_checks="

cp conf/postfix_outgoing_mail_header_filters /etc/postfix/outgoing_mail_header_filters

# TLS and LMTP configuration (independent of public IP/hostname values).
tools/editconf.py /etc/postfix/main.cf \
	smtpd_tls_security_level=may\
	smtpd_tls_auth_only=yes \
	smtpd_tls_cert_file="$STORAGE_ROOT/ssl/ssl_certificate.pem" \
	smtpd_tls_key_file="$STORAGE_ROOT/ssl/ssl_private_key.pem" \
	smtpd_tls_protocols="!SSLv2,!SSLv3" \
	smtpd_tls_ciphers=medium \
	tls_medium_cipherlist=ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA256:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA \
	smtpd_tls_exclude_ciphers=aNULL,RC4 \
	tls_preempt_cipherlist=no \
	smtpd_tls_received_header=yes

tools/editconf.py /etc/postfix/main.cf \
	smtpd_tls_mandatory_protocols="!SSLv2,!SSLv3,!TLSv1,!TLSv1.1" \
	smtpd_tls_mandatory_ciphers=high \
	tls_high_cipherlist=ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384 \
	smtpd_tls_mandatory_exclude_ciphers=aNULL,DES,3DES,MD5,DES+MD5,RC4

tools/editconf.py /etc/postfix/main.cf "virtual_transport=lmtp:[127.0.0.1]:10025"
tools/editconf.py /etc/postfix/main.cf  -e lmtp_destination_recipient_limit=

# Sender/recipient restrictions and greylisting defaults (no PUBLIC_* usage).
tools/editconf.py /etc/postfix/main.cf \
	smtpd_sender_restrictions="reject_non_fqdn_sender,reject_unknown_sender_domain,reject_authenticated_sender_login_mismatch,reject_rhsbl_sender dbl.spamhaus.org=127.0.1.[2..99]" \
	smtpd_recipient_restrictions="permit_sasl_authenticated,permit_mynetworks,reject_rbl_client zen.spamhaus.org=127.0.0.[2..11],reject_unlisted_recipient,check_policy_service inet:127.0.0.1:10023,check_policy_service inet:127.0.0.1:12340"

tools/editconf.py /etc/default/postgrey \
	POSTGREY_OPTS=\""--inet=127.0.0.1:10023 --delay=180 --dbdir=$STORAGE_ROOT/mail/postgrey/db --user=postgrey --group=postgrey --whitelist-clients=/etc/postgrey/whitelist_clients --whitelist-recipients=/etc/postgrey/whitelist_recipients"\"

# Create Postgrey whitelist update script
SCRIPT_PATH=/usr/local/bin/mailinabox-postgrey-whitelist
cat > "$SCRIPT_PATH" <<'EOF'
#!/bin/bash

# Mail-in-a-Box

if [ ! -f /etc/postgrey/whitelist_clients ] || find /etc/postgrey/whitelist_clients -mtime +28 | grep -q '.' ; then
    if curl https://postgrey.schweikert.ch/pub/postgrey_whitelist_clients --output /tmp/postgrey_whitelist_clients -sS --fail > /dev/null 2>&1 ; then
        if [ "$(file -b --mime-type /tmp/postgrey_whitelist_clients)" = "text/plain" ]; then
            mv /tmp/postgrey_whitelist_clients /etc/postgrey/whitelist_clients
            if command -v s6-svc >/dev/null 2>&1 && [ -d /run/service/postgrey ]; then
                s6-svc -h /run/service/postgrey
            elif command -v service >/dev/null 2>&1; then
                service postgrey restart
            fi
        else
            rm /tmp/postgrey_whitelist_clients
        fi
    fi
fi
EOF
chmod +x "$SCRIPT_PATH"

# Add to dcron (daily at 3am)
CRON_TMP=$(mktemp)
grep -v 'mailinabox-postgrey-whitelist' /etc/crontabs/root >"$CRON_TMP" 2>/dev/null || true
{
    cat "$CRON_TMP"
    echo "# Mail-in-a-Box Postgrey whitelist update (daily at 3am)"
    echo "0 3 * * * $SCRIPT_PATH"
} > /etc/crontabs/root
rm -f "$CRON_TMP"

# Run once on setup if Postgrey is available
if command -v s6-svc >/dev/null 2>&1 && [ -d /run/service/postgrey ]; then
    "$SCRIPT_PATH" || true
fi

tools/editconf.py /etc/postfix/main.cf \
	message_size_limit=134217728

