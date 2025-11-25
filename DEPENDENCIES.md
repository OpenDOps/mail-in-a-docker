# Dependencies

This document lists all dependencies (Alpine `apk` packages and Python `pip` packages) used across all Docker containers in this project, grouped by package name.

**Last Updated**: 2025-01

## Alpine Package Dependencies (apk)

### Packages Used in Multiple Containers

| Package | Version | Used In |
|---------|---------|---------|
| `bash` | `5.2.26-r0` | mailinabox (postgrey-builder, pigeonhole-builder, main), bind, nsd |
| `coreutils` | `9.5-r2` | mailinabox, bind, nsd |
| `curl` | `8.14.1-r2` | mailinabox (postgrey-builder, pigeonhole-builder, main), nginx |
| `tzdata` | `2025b-r0` | mailinabox, bind, nsd |
| `build-base` | `0.5-r3` | mailinabox (postgrey-builder, pigeonhole-builder, main) |
| `tar` | `1.35-r2` | mailinabox (postgrey-builder, main) |
| `wget` | `1.24.5-r0` | mailinabox, nginx, assets |
| `unzip` | `6.0-r14` | mailinabox, nginx, assets |
| `netcat-openbsd` | `1.226-r0` | mailinabox, nginx |
| `python3` | `3.12.12-r0` | mailinabox, nsd |
| `dcron` | `4.5-r9` | mailinabox, nsd |
| `bind` | `9.18.41-r0` | mailinabox (optional), bind |
| `bind-tools` | `9.18.41-r0` | mailinabox (optional), bind |
| `openssh-client-default` | `9.7_p1-r5` | mailinabox, nsd |

### Mailinabox Container Only

#### Build Tools (postgrey-builder stage)

| Package | Version |
|---------|---------|
| `perl` | `5.38.5-r0` |
| `perl-dev` | `5.38.5-r0` |
| `perl-app-cpanminus` | `1.7047-r0` |
| `perl-dbi` | `1.643-r6` |
| `perl-dbd-sqlite` | `1.74-r0` |
| `perl-net-dns` | `1.45-r0` |
| `perl-netaddr-ip` | `4.079-r12` |
| `perl-ldap` | `0.68-r2` |
| `perl-net-server` | `2.014-r2` |
| `perl-io-socket-ssl` | `2.085-r0` |
| `perl-io-socket-inet6` | `2.73-r2` |
| `perl-io-multiplex` | `1.16-r5` |
| `perl-crypt-ssleay` | `0.72-r21` |
| `perl-mozilla-ca` | `20240313-r0` |
| `db-dev` | `5.3.28-r5` |

#### Build Tools (pigeonhole-builder stage)

| Package | Version |
|---------|---------|
| `dovecot` | `2.3.21.1-r0` (via DOVECOT_VERSION) |
| `dovecot-dev` | `2.3.21.1-r0` (via DOVECOT_VERSION) |
| `autoconf` | `2.72-r0` |
| `automake` | `1.16.5-r2` |
| `libtool` | `2.4.7-r3` |
| `pkgconf` | `2.2.0-r0` |
| `openssl-dev` | `3.3.5-r0` |
| `zlib-dev` | `1.3.1-r1` |
| `xz` | `5.6.2-r1` |

#### Runtime Dependencies (main stage)

| Package | Version |
|---------|---------|
| `bc` | `1.07.1-r4` |
| `ca-certificates` | `20250911-r0` |
| `chrony` | `4.5-r0` |
| `dcron` | `4.5-r9` |
| `file` | `5.45-r1` |
| `git` | `2.45.4-r0` |
| `linux-headers` | `6.6-r0` |
| `musl-locales` | `0.1.0-r1` |
| `musl-locales-lang` | `0.1.0-r1` |
| `openssh-client-default` | `9.7_p1-r5` |
| `postfix` | `3.9.6-r0` |
| `postfix-sqlite` | `3.9.6-r0` |
| `postfix-pcre` | `3.9.6-r0` |
| `python3` | `3.12.12-r0` |
| `python3-dev` | `3.12.12-r0` |
| `py3-pip` | `24.0-r2` |
| `py3-setuptools` | `70.3.0-r0` |
| `py3-wheel` | `0.42.0-r1` |
| `rsync` | `3.4.0-r0` |
| `rsyslog` | `8.2404.0-r0` |
| `sudo` | `1.9.15_p5-r0` |
| `perl` | `5.38.5-r0` |
| `perl-dbi` | `1.643-r6` |
| `perl-dbd-sqlite` | `1.74-r0` |
| `perl-net-dns` | `1.45-r0` |
| `perl-netaddr-ip` | `4.079-r12` |
| `perl-ldap` | `0.68-r2` |
| `perl-net-server` | `2.014-r2` |
| `perl-io-socket-ssl` | `2.085-r0` |
| `perl-io-socket-inet6` | `2.73-r2` |
| `perl-io-multiplex` | `1.16-r5` |
| `perl-crypt-ssleay` | `0.72-r21` |
| `perl-mozilla-ca` | `20240313-r0` |
| `db` | `5.3.28-r5` |
| `dovecot` | `2.3.21.1-r0` (via DOVECOT_VERSION) |
| `dovecot-lmtpd` | `2.3.21.1-r0` (via DOVECOT_VERSION) |
| `dovecot-sqlite` | `2.3.21.1-r0` (via DOVECOT_VERSION) |
| `sqlite` | `3.45.3-r2` |
| `opendkim` | `2.11.0-r3` |
| `opendkim-utils` | `2.11.0-r3` |
| `opendmarc` | `1.4.2-r1` |
| `duplicity` | `2.2.3-r1` |
| `py3-virtualenv` | `20.28.0-r0` |
| `openssl` | `3.3.5-r0` (optional, if WITH_SSL=true) |
| `certbot` | `2.10.0-r1` (optional, if WITH_SSL=true) |
| `bind` | `9.18.41-r0` (optional, if ENABLE_INTERNAL_BIND=true) |
| `bind-tools` | `9.18.41-r0` (optional, if ENABLE_INTERNAL_BIND=true) |

### Nginx Container Only

| Package | Version |
|---------|---------|
| `nginx` | `1.26.3-r0` |
| `gettext` | `0.22.5-r0` |
| `libidn2` | `2.3.7-r0` nginx, assets |
| `idn2-utils` | `2.3.7-r0` nginx, assets |
| `php82` | `8.2.28-r0` (optional, if WITH_PHP=true) |
| `php82-fpm` | `8.2.28-r0` (optional, if WITH_PHP=true) |
| `php82-cli` | `8.2.28-r0` (optional, if WITH_PHP=true) |
| `php82-gd` | `8.2.28-r0` (optional, if WITH_PHP=true) |
| `php82-intl` | `8.2.28-r0` (optional, if WITH_PHP=true) |
| `php82-imap` | `8.2.28-r0` (optional, if WITH_PHP=true) |
| `php82-curl` | `8.2.28-r0` (optional, if WITH_PHP=true) |
| `php82-xml` | `8.2.28-r0` (optional, if WITH_PHP=true) |
| `php82-mbstring` | `8.2.28-r0` (optional, if WITH_PHP=true) |
| `php82-zip` | `8.2.28-r0` (optional, if WITH_PHP=true) |
| `php82-pecl-apcu` | `5.1.23-r0` (optional, if WITH_PHP=true) |
| `php82-pecl-imagick` | `3.7.0-r6` (optional, if WITH_PHP=true) |
| `php82-gmp` | `8.2.28-r0` (optional, if WITH_PHP=true) |
| `php82-bcmath` | `8.2.28-r0` (optional, if WITH_PHP=true) |
| `php82-sqlite3` | `8.2.28-r0` (optional, if WITH_PHP=true) |
| `php82-soap` | `8.2.28-r0` (optional, if WITH_PHP=true) |

### Bind Container Only

| Package | Version |
|---------|---------|
| `bind` | `9.18.41-r0` |
| `bind-tools` | `9.18.41-r0` |
| `jq` | `1.7.1-r0` |

### NSD Container Only

| Package | Version |
|---------|---------|
| `nsd` | `4.9.1-r0` |
| `ldns` | `1.8.3-r2` |
| `ldns-tools` | `1.8.3-r2` |
| `logrotate` | `3.21.0-r1` |

## Python Package Dependencies (pip)

### System-wide Packages (requirements-system.txt)

These packages are installed system-wide (with `--break-system-packages`) and are used by duplicity for backups.

| Package | Version | Used In |
|---------|---------|---------|
| `b2sdk` | `1.23.0` | mailinabox |
| `boto3` | `1.34.0` | mailinabox |

### Management Daemon Packages (requirements.txt)

These packages are installed in a virtualenv at `/usr/local/lib/mailinabox/env` for the Mail-in-a-Box management daemon.

| Package | Version | Used In |
|---------|---------|---------|
| `rtyaml` | `1.0.0` | mailinabox |
| `email_validator` | `2.1.0` | mailinabox |
| `exclusiveprocess` | `0.9.4` | mailinabox |
| `flask` | `3.0.0` | mailinabox |
| `dnspython` | `2.4.2` | mailinabox |
| `python-dateutil` | `2.8.2` | mailinabox |
| `expiringdict` | `1.2.2` | mailinabox |
| `gunicorn` | `21.2.0` | mailinabox |
| `qrcode[pil]` | `7.4.2` | mailinabox |
| `pyotp` | `2.9.0` | mailinabox |
| `idna` | `3.6` | mailinabox |
| `cryptography` | `37.0.2` | mailinabox |
| `psutil` | `5.9.6` | mailinabox |
| `postfix-mta-sts-resolver` | `1.0.0` | mailinabox |

## External Dependencies

### Source-built Packages

These packages are built from source during the Docker build process:

| Package | Version | Source | Used In |
|---------|---------|--------|---------|
| `postgrey` | `1.37` | Debian source | mailinabox |
| `dovecot-pigeonhole` | `0.5.21` | Pigeonhole source | mailinabox |
| `BerkeleyDB` | (via cpanm) | CPAN | mailinabox (for postgrey) |

### External Tools

| Tool | Version | Source | Used In |
|------|---------|--------|---------|
| `s6-overlay` | `v3.1.5.0` | GitHub releases | mailinabox, nginx |
| `jquery` | `2.2.4` | code.jquery.com | mailinabox |
| `bootstrap` | `3.4.1` | GitHub releases | mailinabox |

## Version Pinning

All dependencies are pinned to exact versions for security reasons. This prevents supply chain attacks by ensuring reproducible builds and avoiding unexpected updates.

### Updating Dependencies

To update dependencies:

1. **Alpine packages**: Run `./scripts/pin-package-versions.sh <package>` to get the latest version
2. **Python packages**: Check PyPI for latest versions and update `requirements.txt` or `requirements-system.txt`
3. **Test thoroughly**: Always test in a development environment before updating production

See [SECURITY.md](SECURITY.md) for more information on version pinning and security practices.

## Container Summary

| Container | APK Packages | Python Packages | Notes |
|-----------|---------------|-----------------|-------|
| **mailinabox** | ~60 packages | 15 packages | Main container with mail services and management daemon |
| **nginx** | 6-20 packages | 0 | Web server (PHP packages optional) |
| **bind** | 5 packages | 0 | Optional recursive DNS resolver |
| **nsd** | 10 packages | 0 | Authoritative DNS server |
