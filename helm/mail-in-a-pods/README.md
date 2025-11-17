# Mail-in-a-Box Helm Chart

This Helm chart deploys Mail-in-a-Box on Kubernetes using the Gateway API for routing and cert-manager for automatic TLS certificate management.

## Prerequisites

- Kubernetes 1.19+ with Gateway API support
- Helm 3.0+
- Gateway API controller installed (e.g., nginx Gateway Fabric, Istio, etc.)
- cert-manager installed (optional, for automatic TLS certificates)

## Installation

### 1. Install cert-manager (if not already installed)

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

### 2. Configure values.yaml

Before installing, configure the following required values:

```yaml
global:
  primaryHostname: "box.example.com"  # Your mail server hostname

certManager:
  enabled: true
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory  # Production
    email: "your-email@example.com"  # Required: Your email for Let's Encrypt

gateway:
  enabled: true
  className: "nginx"  # Your GatewayClass name
```

### 3. Install the chart

```bash
helm install mailinabox ./helm/mail-in-a-pods
```

## Configuration

The following table lists the key configurable parameters and their default values:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.primaryHostname` | Primary hostname for the mail server | `box.example.com` |
| `mailinabox.storage.size` | Size of mail storage PVC | `50Gi` |
| `gateway.enabled` | Enable Gateway API | `true` |
| `gateway.className` | GatewayClass name | `nginx` |
| `certManager.enabled` | Enable cert-manager integration | `true` |
| `certManager.acme.server` | ACME server URL | `https://acme-v02.api.letsencrypt.org/directory` |
| `certManager.acme.email` | Email for Let's Encrypt notifications | `""` (required) |
| `nsd.enabled` | Enable NSD authoritative DNS | `true` |
| `bind.enabled` | Enable BIND recursive resolver | `false` |

See `values.yaml` for all available configuration options.

## Key Differences from Docker Compose

1. **No nginx container**: Replaced with Kubernetes Gateway API
2. **Gateway API**: Uses Gateway, HTTPRoute, TCPRoute, and TLSRoute resources for routing
3. **Automatic ClusterIssuer**: The chart creates a ClusterIssuer automatically for cert-manager
4. **Cert-manager integration**: TLS certificates are managed by cert-manager and mounted as secrets
5. **PersistentVolumes**: All volumes are converted to PersistentVolumeClaims
6. **Service discovery**: Uses Kubernetes DNS instead of Docker network IPs
7. **Certificate paths**: Mail-in-a-Box reads certificates from `/etc/ssl/certs/tls.crt` and `/etc/ssl/private/tls.key` (mounted from cert-manager secret)

## Gateway API Configuration

The chart uses the Kubernetes Gateway API for routing:

- **Gateway**: Defines listeners for HTTP (80), HTTPS (443), SMTP (25), IMAP (143), IMAPS (993), SMTPS (465), and Submission (587)
- **HTTPRoute**: Routes HTTP/HTTPS traffic to the mailinabox service
- **TCPRoute**: Routes plain TCP traffic for SMTP (25) and IMAP (143)
- **TLSRoute**: Routes TLS-encrypted traffic for IMAPS (993), SMTPS (465), and Submission (587) with SNI-based hostname routing

### Multi-Domain Support

You can configure multiple domains with separate TLS certificates:

```yaml
gateway:
  tls:
    - hostname: ""  # Empty means use global.primaryHostname
      secretName: "mailinabox-tls"
    - hostname: "mail.example.com"
      secretName: "mail-example-com-tls"
```

## Certificate Management

Certificates are automatically provisioned by cert-manager when:

- `certManager.enabled` is `true`
- `gateway.enabled` is `true`
- TLS configuration is provided in `gateway.tls`

### Automatic ClusterIssuer Creation

The chart automatically creates a ClusterIssuer named `{release-name}-cert-issuer` that:

- Uses HTTP-01 challenge via Gateway API
- References the Gateway created by this chart
- Supports configurable nodeSelector, tolerations, and affinity for solver pods

### How Certificates Are Mounted

1. **ClusterIssuer** (`clusterissuer.yaml`) is created automatically with Gateway API HTTP-01 solver
2. **Certificate resource** (`certificate.yaml`) requests a certificate from the ClusterIssuer
3. **cert-manager creates a Kubernetes Secret** with keys: `tls.crt`, `tls.key`, `ca.crt`
4. **The secret is referenced in Gateway** for TLS termination at the gateway level
5. **The same secret is mounted in the mailinabox pod** as volumes:
   - Certificate: `/etc/ssl/certs/tls.crt`
   - Private key: `/etc/ssl/private/tls.key`
6. **Environment variables** (`SSL_CERTIFICATE`, `SSL_KEY`) point mailinabox services to these paths

**Key points:**

- Single source of truth: cert-manager Certificate resource
- Automatic renewal: cert-manager renews certificates before expiration
- Automatic updates: When the secret is updated, Kubernetes automatically updates mounted volumes
- Dual usage: Same secret used by both Gateway and mailinabox services
- Gateway API integration: HTTP-01 challenges are handled via Gateway API HTTPRoute

See `CERTIFICATE_MOUNTING.md` for detailed explanation.

## Storage

All persistent volumes are created as PersistentVolumeClaims. Make sure your cluster has a default StorageClass or specify one in `values.yaml`.

## DNS Configuration

- **NSD**: Authoritative DNS server (enabled by default)
- **BIND**: Recursive resolver (disabled by default, enable if your cluster DNS doesn't support DNSSEC validation)

## Uninstallation

```bash
helm uninstall mailinabox
```

Note: This will NOT delete PersistentVolumeClaims. To remove them manually:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=mailinabox
```
