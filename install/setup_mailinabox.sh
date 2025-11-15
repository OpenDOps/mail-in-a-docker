#!/bin/bash

source setup/functions.sh
source /etc/mailinabox.conf # load global vars

echo "Installing Mail-in-a-Box system management daemon...."

# Installation directory and virtualenv already created in Dockerfile
inst_dir=/usr/local/lib/mailinabox
venv=$inst_dir/env

# Create an init script to start the management daemon and keep it
# running after a reboot.
# Set a long timeout since some commands take a while to run, matching
# the timeout we set for PHP (fastcgi_read_timeout in the nginx confs).
# Note: Authentication currently breaks with more than 1 gunicorn worker.
cat > $inst_dir/start <<EOF
#!/bin/bash
# Set character encoding flags to ensure that any non-ASCII don't cause problems.
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_TYPE=en_US.UTF-8

mkdir -p /var/lib/mailinabox
tr -cd '[:xdigit:]' < /dev/urandom | head -c 32 > /var/lib/mailinabox/api.key
chmod 640 /var/lib/mailinabox/api.key

# Activate virtualenv and set Python path
# PYTHONPATH should point to the management directory so wsgi can be imported directly
# Bind to 0.0.0.0 (not localhost) so nginx in a separate container can access it
source ${venv}/bin/activate
export PYTHONPATH=/opt/MailInABox/management
cd /opt/MailInABox/management
exec gunicorn -b 0.0.0.0:10222 -w 1 --timeout 630 wsgi:app
EOF

chmod +x $inst_dir/start

# Perform nightly tasks at 3am in system time: take a backup, run
# status checks and email the administrator any changes. Install into dcron.

minute=$((RANDOM % 60))  # avoid overloading mailinabox.email
CRON_TMP=$(mktemp)
grep -v 'management/daily_tasks.sh' /etc/crontabs/root >"$CRON_TMP" 2>/dev/null || true
{
    cat "$CRON_TMP"
    echo "# Mail-in-a-Box nightly tasks"
    echo "$minute 1 * * * cd $PWD && /bin/sh management/daily_tasks.sh"
} > /etc/crontabs/root
rm -f "$CRON_TMP"

echo "DEBUG: setup_mailinabox.sh - Installed nightly tasks"

# s6 will launch the service automatically; no explicit restart needed.
echo "DEBUG: setup_mailinabox.sh - Mailinabox installed"