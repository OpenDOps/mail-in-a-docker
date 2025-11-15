#!/bin/bash
set -euo pipefail

cd /opt/MailInABox

source /opt/install/functions.sh
source /etc/mailinabox.conf

# Setting a `postmaster_address` is required or LMTP won't start. An alias
# will be created automatically by our management daemon.
tools/editconf.py /etc/dovecot/conf.d/15-lda.conf \
	"postmaster_address=postmaster@$PRIMARY_HOSTNAME"

# Ensure mailbox files have a directory that exists and are owned by the mail user.
mkdir -p "$STORAGE_ROOT/mail/mailboxes"
chown -R mail:mail "$STORAGE_ROOT/mail/mailboxes"

# Same for the sieve scripts.
mkdir -p "$STORAGE_ROOT/mail/sieve"
mkdir -p "$STORAGE_ROOT/mail/sieve/global_before"
mkdir -p "$STORAGE_ROOT/mail/sieve/global_after"
chown -R mail:mail "$STORAGE_ROOT/mail/sieve"