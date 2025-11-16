#!/bin/sh
set -eu

if [ "${INSTALL_FAIL2BAN:-false}" != "true" ]; then
    exit 0
fi

apk add --no-cache fail2ban

mkdir -p /etc/fail2ban/jail.d /etc/fail2ban/filter.d
cp /opt/MailInABox/conf/fail2ban/jails.conf /etc/fail2ban/jail.d/mailinabox.conf
cp /opt/MailInABox/conf/fail2ban/filter.d/* /etc/fail2ban/filter.d/

sed -i "s#STORAGE_ROOT#${STORAGE_ROOT:-/home/user-data}#g" /etc/fail2ban/jail.d/mailinabox.conf
