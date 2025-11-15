# Creates an nginx configuration file so we serve HTTP/HTTPS on all
# domains for which a mail account has been set up.
########################################################################

import os, os.path, re, rtyaml, subprocess, tempfile

# Load environment variables from /etc/mailinabox.conf before any functions are called
# This ensures all environment variables are available throughout the module
try:
	from utils import load_environment
	# Load environment at module level so it's available to all functions
	_module_env = load_environment()
	# Export key variables to os.environ so they're available to subprocesses
	for key, value in _module_env.items():
		if key not in os.environ:
			os.environ[key] = str(value)
except Exception:
	# If loading fails (e.g., during import before setup), that's okay
	# Functions will receive env as a parameter anyway
	_module_env = None
	pass

from mailconfig import get_mail_domains
from dns_update import get_custom_dns_config, get_dns_zones
from ssl_certificates import get_ssl_certificates, get_domain_ssl_files, check_certificate
from utils import shell, safe_domain_name, sort_domains

def get_web_domains(env, include_www_redirects=True, include_auto=True, exclude_dns_elsewhere=True):
	# What domains should we serve HTTP(S) for?
	domains = set()

	# Serve web for all mail domains so that we might at least
	# provide auto-discover of email settings, and also a static website
	# if the user wants to make one.
	domains |= get_mail_domains(env)

	if include_www_redirects and include_auto:
		# Add 'www.' subdomains that we want to provide default redirects
		# to the main domain for. We'll add 'www.' to any DNS zones, i.e.
		# the topmost of each domain we serve.
		domains |= {'www.' + zone for zone, zonefile in get_dns_zones(env)}

	if include_auto:
		# Add Autoconfiguration domains for domains that there are user accounts at:
		# 'autoconfig.' for Mozilla Thunderbird auto setup.
		# 'autodiscover.' for ActiveSync autodiscovery (Z-Push).
		domains |= {'autoconfig.' + maildomain for maildomain in get_mail_domains(env, users_only=True)}
		domains |= {'autodiscover.' + maildomain for maildomain in get_mail_domains(env, users_only=True)}

		# 'mta-sts.' for MTA-STS support for all domains that have email addresses.
		domains |= {'mta-sts.' + maildomain for maildomain in get_mail_domains(env)}

	if exclude_dns_elsewhere:
		# ...Unless the domain has an A/AAAA record that maps it to a different
		# IP address than this box. Remove those domains from our list.
		domains -= get_domains_with_a_records(env)

	# Ensure the PRIMARY_HOSTNAME is in the list so we can serve webmail
	# as well as Z-Push for Exchange ActiveSync. This can't be removed
	# by a custom A/AAAA record and is never a 'www.' redirect.
	domains.add(env['PRIMARY_HOSTNAME'])

	# Sort the list so the nginx conf gets written in a stable order.
	return sort_domains(domains, env)


def get_domains_with_a_records(env):
	domains = set()
	dns = get_custom_dns_config(env)
	for domain, rtype, value in dns:
		if rtype == "CNAME" or (rtype in {"A", "AAAA"} and value not in {"local", env['PUBLIC_IP'], env['PUBLIC_IPV6']}):
			domains.add(domain)
	return domains

def get_web_domains_with_root_overrides(env):
	# Load custom settings so we can tell what domains have a redirect or proxy set up on '/',
	# which means static hosting is not happening.
	root_overrides = { }
	nginx_conf_custom_fn = os.path.join(env["STORAGE_ROOT"], "www/custom.yaml")
	if os.path.exists(nginx_conf_custom_fn):
		with open(nginx_conf_custom_fn, encoding='utf-8') as f:
			custom_settings = rtyaml.load(f)
		for domain, settings in custom_settings.items():
			for type, value in [('redirect', settings.get('redirects', {}).get('/')),
				('proxy', settings.get('proxies', {}).get('/'))]:
				if value:
					root_overrides[domain] = (type, value)
	return root_overrides

def do_web_update(env):
	import sys

	# Pre-load what SSL certificates we will use for each domain.
	ssl_certificates = get_ssl_certificates(env)

	# Helper for reading config files and templates
	def read_conf(conf_fn):
		with open(os.path.join(os.path.dirname(__file__), "/opt/mailinabox-config/", conf_fn), encoding='utf-8') as f:
			return f.read()

	# Build an nginx configuration file.
	nginx_conf = read_conf("nginx-top.conf")

	php_ver = env.get('PHP_VER', '8.2')
	
	print(f"DEBUG: Replacing php socket path with correct PHP version: {php_ver}", file=sys.stderr, flush=True)
	# Replace PHP-FPM socket path with correct PHP version for Docker/Alpine
	# In Docker/Alpine, PHP versions are like php82 (not php8.2)
	# Get PHP version from environment, default to 8.2
	php_ver = env.get('PHP_VER', '8.2')
	# Convert 8.2 to 82 for Alpine package naming
	php_ver_dir = php_ver.replace('.', '')
	# Replace the hardcoded php8.0-fpm.sock with the correct version
	nginx_conf = re.sub(
		r'unix:/var/run/php/php\d+\.\d+-fpm\.sock',
		f'unix:/var/run/php/php{php_ver_dir}-fpm.sock',
		nginx_conf
	)

	# Load the templates.
	template0 = read_conf("nginx.conf")
	template1 = read_conf("nginx-alldomains.conf")
	template2 = read_conf("nginx-primaryonly.conf")
	template3 = "\trewrite ^(.*) https://$REDIRECT_DOMAIN$1 permanent;\n"

	# Add the PRIMARY_HOST configuration first so it becomes nginx's default server.
	nginx_conf += make_domain_config(env['PRIMARY_HOSTNAME'], [template0, template1, template2], ssl_certificates, env)

	# Add configuration all other web domains.
	has_root_proxy_or_redirect = get_web_domains_with_root_overrides(env)
	web_domains_not_redirect = get_web_domains(env, include_www_redirects=False)
	for domain in get_web_domains(env):
		if domain == env['PRIMARY_HOSTNAME']:
			# PRIMARY_HOSTNAME is handled above.
			continue
		if domain in web_domains_not_redirect:
			# This is a regular domain.
			if domain not in has_root_proxy_or_redirect:
				nginx_conf += make_domain_config(domain, [template0, template1], ssl_certificates, env)
			else:
				nginx_conf += make_domain_config(domain, [template0], ssl_certificates, env)
		else:
			# Add default 'www.' redirect.
			nginx_conf += make_domain_config(domain, [template0, template3], ssl_certificates, env)

	# Determine nginx config location
	# In Kubernetes, skip nginx config generation (use Ingress resources instead)
	# In Docker setup with separate nginx container, write to shared volume
	# Otherwise, write to standard location
	if env.get('IN_KUBERNETES', 'false') == 'true':
		# Kubernetes setup: nginx configs not needed, use Ingress resources instead
		# TODO: Generate Ingress resources dynamically using Kubernetes API
		print(f"DEBUG: Kubernetes mode detected - skipping nginx config generation", file=sys.stderr, flush=True)
		print(f"DEBUG: Ingress resources should be managed via Kubernetes API", file=sys.stderr, flush=True)
		return "web updated (Kubernetes mode - using Ingress resources)\n"
	elif env.get('IN_A_DOCKER', 'false') == 'true':
		# Docker setup: nginx runs in separate container, use shared volume
		nginx_config_dir = "/var/lib/mailinabox/nginx-config"
		nginx_conf_fn = os.path.join(nginx_config_dir, "local.conf")
		use_docker_volume = True
		print(f"DEBUG: Using Docker volume: {nginx_config_dir}", file=sys.stderr, flush=True)
	else:
		# Standard setup: nginx runs on same system
		nginx_config_dir = "/etc/nginx/conf.d"
		nginx_conf_fn = os.path.join(nginx_config_dir, "local.conf")
		use_docker_volume = False
		print(f"DEBUG: Using standard location: {nginx_config_dir}", file=sys.stderr, flush=True)

	# Ensure directory exists
	os.makedirs(nginx_config_dir, exist_ok=True)
	print(f"DEBUG: Created/verified directory: {nginx_config_dir}", file=sys.stderr, flush=True)

	# Did the file change? If not, don't bother writing & signaling nginx.
	if os.path.exists(nginx_conf_fn):
		with open(nginx_conf_fn, encoding='utf-8') as f:
			if f.read() == nginx_conf:
				return ""

	# Save the file.
	with open(nginx_conf_fn, "w", encoding='utf-8') as f:
		f.write(nginx_conf)

	# Signal nginx to reload
	if use_docker_volume:
		# Docker setup: signal via reload trigger file (nginx container watches this)
		reload_trigger = os.path.join(nginx_config_dir, ".reload")
		print(f"DEBUG: Creating reload trigger: {reload_trigger}", file=sys.stderr, flush=True)
		with open(reload_trigger, "w") as f:
			f.write(str(os.path.getmtime(nginx_conf_fn)))
	else:
		# Standard setup: reload nginx service directly
		print(f"DEBUG: Reloading nginx service directly", file=sys.stderr, flush=True)
		shell('check_call', ["/usr/sbin/service", "nginx", "reload"])

	print("DEBUG: do_web_update() completed successfully", file=sys.stderr, flush=True)
	return "web updated\n"

def make_domain_config(domain, templates, ssl_certificates, env):
	# GET SOME VARIABLES

	# Where will its root directory be for static files?
	root = get_web_root(domain, env)
  
	tls_cert = get_domain_ssl_files(domain, ssl_certificates, env)

	# ADDITIONAL DIRECTIVES.

	nginx_conf_extra = ""

	# Because the certificate may change, we should recognize this so we
	# can trigger an nginx update.
	def hashfile(filepath):
		import hashlib
		if not os.path.exists(filepath):
			return "missing"
		sha1 = hashlib.sha1()
		try:
			with open(filepath, 'rb') as f:
				sha1.update(f.read())
			return sha1.hexdigest()
		except (OSError, IOError):
			return "error"
	nginx_conf_extra += "\t# ssl files sha1: {} / {}\n".format(hashfile(tls_cert["private-key"]), hashfile(tls_cert["certificate"]))

	# Add in any user customizations in YAML format.
	hsts = "yes"
	nginx_conf_custom_fn = os.path.join(env["STORAGE_ROOT"], "www/custom.yaml")
	if os.path.exists(nginx_conf_custom_fn):
		with open(nginx_conf_custom_fn, encoding='utf-8') as f:
			yaml = rtyaml.load(f)
		if domain in yaml:
			yaml = yaml[domain]

			# any proxy or redirect here?
			for path, url in yaml.get("proxies", {}).items():
				# Parse some flags in the fragment of the URL.
				pass_http_host_header = False
				proxy_redirect_off = False
				frame_options_header_sameorigin = False
				web_sockets = False
				m = re.search(r"#(.*)$", url)
				if m:
					for flag in m.group(1).split(","):
						if flag == "pass-http-host":
							pass_http_host_header = True
						elif flag == "no-proxy-redirect":
							proxy_redirect_off = True
						elif flag == "frame-options-sameorigin":
							frame_options_header_sameorigin = True
						elif flag == "web-sockets":
							web_sockets = True
					url = re.sub(r"#(.*)$", "", url)

				nginx_conf_extra += f"\tlocation {path} {{"
				nginx_conf_extra += f"\n\t\tproxy_pass {url};"
				if proxy_redirect_off:
					nginx_conf_extra += "\n\t\tproxy_redirect off;"
				if pass_http_host_header:
					nginx_conf_extra += "\n\t\tproxy_set_header Host $http_host;"
				if frame_options_header_sameorigin:
					nginx_conf_extra += "\n\t\tproxy_set_header X-Frame-Options SAMEORIGIN;"
				if web_sockets:
					nginx_conf_extra += "\n\t\tproxy_http_version 1.1;"
					nginx_conf_extra += "\n\t\tproxy_set_header Upgrade $http_upgrade;"
					nginx_conf_extra += "\n\t\tproxy_set_header Connection 'Upgrade';"
				nginx_conf_extra += "\n\t\tproxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;"
				nginx_conf_extra += "\n\t\tproxy_set_header X-Forwarded-Host $http_host;"
				nginx_conf_extra += "\n\t\tproxy_set_header X-Forwarded-Proto $scheme;"
				nginx_conf_extra += "\n\t\tproxy_set_header X-Real-IP $remote_addr;"
				nginx_conf_extra += "\n\t}\n"
			for path, alias in yaml.get("aliases", {}).items():
				nginx_conf_extra += f"\tlocation {path} {{"
				nginx_conf_extra += f"\n\t\talias {alias};"
				nginx_conf_extra += "\n\t}\n"
			for path, url in yaml.get("redirects", {}).items():
				nginx_conf_extra += f"\trewrite {path} {url} permanent;\n"

			# override the HSTS directive type
			hsts = yaml.get("hsts", hsts)

	# Add the HSTS header.
	if hsts == "yes":
		nginx_conf_extra += '\tadd_header Strict-Transport-Security "max-age=15768000" always;\n'
	elif hsts == "preload":
		nginx_conf_extra += '\tadd_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload" always;\n'

	# Add in any user customizations in the includes/ folder.
	nginx_conf_custom_include = os.path.join(env["STORAGE_ROOT"], "www", safe_domain_name(domain) + ".conf")
	if os.path.exists(nginx_conf_custom_include):
		nginx_conf_extra += f"\tinclude {nginx_conf_custom_include};\n"
	# PUT IT ALL TOGETHER

	# Combine the pieces. Iteratively place each template into the "# ADDITIONAL DIRECTIVES HERE" placeholder
	# of the previous template.
	nginx_conf = "# ADDITIONAL DIRECTIVES HERE\n"
	for t in [*templates, nginx_conf_extra]:
		nginx_conf = re.sub("[ \t]*# ADDITIONAL DIRECTIVES HERE *\n", t, nginx_conf)

	# Replace substitution strings in the template & return.
	nginx_conf = nginx_conf.replace("$STORAGE_ROOT", env['STORAGE_ROOT'])
	nginx_conf = nginx_conf.replace("$HOSTNAME", domain)
	nginx_conf = nginx_conf.replace("$ROOT", root)
	nginx_conf = nginx_conf.replace("$SSL_KEY", tls_cert["private-key"])
	nginx_conf = nginx_conf.replace("$SSL_CERTIFICATE", tls_cert["certificate"])
	return nginx_conf.replace("$REDIRECT_DOMAIN", re.sub(r"^www\.", "", domain)) # for default www redirects to parent domain


def get_web_root(domain, env, test_exists=True):
	# Try STORAGE_ROOT/web/domain_name if it exists, but fall back to STORAGE_ROOT/web/default.
	for test_domain in (domain, 'default'):
		root = os.path.join(env["STORAGE_ROOT"], "www", safe_domain_name(test_domain))
		if os.path.exists(root) or not test_exists: break
	return root

# def create_placeholder_certificate(domain, env):
# 	"""Create a placeholder self-signed SSL certificate if one doesn't exist.
# 	This allows nginx to start even before a real certificate is provisioned."""
# 	ssl_dir = os.path.join(env["STORAGE_ROOT"], 'ssl')
# 	os.makedirs(ssl_dir, exist_ok=True)

# 	ssl_private_key = os.path.join(ssl_dir, 'ssl_private_key.pem')
# 	ssl_certificate = os.path.join(ssl_dir, 'ssl_certificate.pem')

# 	# Create private key if it doesn't exist
# 	if not os.path.exists(ssl_private_key):
# 		import sys
# 		print(f"DEBUG: Creating placeholder private key: {ssl_private_key}", file=sys.stderr, flush=True)
# 		subprocess.check_call([
# 			"openssl", "genrsa", "-out", ssl_private_key, "2048"
# 		], stderr=subprocess.DEVNULL)
# 		os.chmod(ssl_private_key, 0o600)

# 	# Create self-signed certificate if it doesn't exist
# 	if not os.path.exists(ssl_certificate):
# 		import sys
# 		print(f"DEBUG: Creating placeholder self-signed certificate: {ssl_certificate}", file=sys.stderr, flush=True)
# 		# Create a temporary CSR
# 		with tempfile.NamedTemporaryFile(mode='w', suffix='.csr', delete=False) as csr_file:
# 			csr_path = csr_file.name

# 		try:
# 			# Generate CSR
# 			subprocess.check_call([
# 				"openssl", "req", "-new", "-key", ssl_private_key,
# 				"-out", csr_path, "-subj", f"/CN={domain}"
# 			], stderr=subprocess.DEVNULL)

# 			# Generate self-signed certificate (valid for 365 days)
# 			subprocess.check_call([
# 				"openssl", "x509", "-req", "-days", "365",
# 				"-in", csr_path, "-signkey", ssl_private_key,
# 				"-out", ssl_certificate, "-sha256"
# 			], stderr=subprocess.DEVNULL)

# 			os.chmod(ssl_certificate, 0o644)
# 		finally:
# 			# Clean up CSR file
# 			if os.path.exists(csr_path):
# 				os.unlink(csr_path)

# 	# Return certificate info
# 	return {
# 		"private-key": ssl_private_key,
# 		"certificate": ssl_certificate,
# 		"primary-domain": domain,
# 	}

def get_web_domains_info(env):
	www_redirects = set(get_web_domains(env)) - set(get_web_domains(env, include_www_redirects=False))
	has_root_proxy_or_redirect = set(get_web_domains_with_root_overrides(env))
	ssl_certificates = get_ssl_certificates(env)

	# for the SSL config panel, get cert status
	def check_cert(domain):
		try:
			tls_cert = get_domain_ssl_files(domain, ssl_certificates, env, allow_missing_cert=True)
		except OSError: # PRIMARY_HOSTNAME cert is missing
			tls_cert = None
		if tls_cert is None: return ("danger", "No certificate installed.")
		cert_status, cert_status_details = check_certificate(domain, tls_cert["certificate"], tls_cert["private-key"])
		if cert_status == "OK":
			return ("success", "Signed & valid. " + cert_status_details)
		if cert_status == "SELF-SIGNED":
			return ("warning", "Self-signed. Get a signed certificate to stop warnings.")
		return ("danger", "Certificate has a problem: " + cert_status)

	return [
		{
			"domain": domain,
			"root": get_web_root(domain, env),
			"custom_root": get_web_root(domain, env, test_exists=False),
			"ssl_certificate": check_cert(domain),
			"static_enabled": domain not in (www_redirects | has_root_proxy_or_redirect),
		}
		for domain in get_web_domains(env)
	]

