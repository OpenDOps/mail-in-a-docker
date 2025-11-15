#!/bin/bash
set -euo pipefail

cd /opt/MailInABox

source /opt/install/functions.sh
source /etc/mailinabox.conf

# Create the dkim directory
mkdir -p "$STORAGE_ROOT/mail/dkim"

# Create a new DKIM key. This creates mail.private and mail.txt
# in $STORAGE_ROOT/mail/dkim. The former is the private key and
# the latter is the suggested DNS TXT entry which we'll include
# in our DNS setup. Note that the files are named after the
# 'selector' of the key, which we can change later on to support
# key rotation.
#
# A 1024-bit key is seen as a minimum standard by several providers
# such as Google. But they and others use a 2048 bit key, so we'll
# do the same. Keys beyond 2048 bits may exceed DNS record limits.
if [ ! -f "$STORAGE_ROOT/mail/dkim/mail.private" ]; then
	opendkim-genkey -b 2048 -r -s mail -D "$STORAGE_ROOT/mail/dkim"
fi

# Ensure files are owned by the opendkim user and are private otherwise.
chown -R opendkim:opendkim "$STORAGE_ROOT/mail/dkim"
chmod go-rwx "$STORAGE_ROOT/mail/dkim"