# Certificate Mounting from cert-manager to mailinabox

## Overview

Cert-manager generates TLS certificates and stores them in Kubernetes Secrets. These secrets are then mounted into the mailinabox container so that mailinabox services (Postfix, Dovecot) can use the certificates for TLS/SSL.

## Certificate Flow

```txt
cert-manager Certificate Resource
    ↓
cert-manager provisions certificate (Let's Encrypt, etc.)
    ↓
Kubernetes Secret created (with keys: tls.crt, tls.key, ca.crt)
    ↓
Secret mounted in mailinabox pod as volumes
    ↓
Certificates available at /etc/ssl/certs/tls.crt and /etc/ssl/private/tls.key
```

## Step-by-Step Process

### 1. Certificate Resource Creation

The `certificate.yaml` template creates a cert-manager Certificate resource:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: mailinabox-tls
spec:
  secretName: mailinabox-tls  # Name of the secret to create
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - box.example.com
```

**What happens:**

- cert-manager watches for Certificate resources
- It requests a certificate from the ClusterIssuer (Let's Encrypt)
- Once issued, it creates a Kubernetes Secret with the certificate data

### 2. Secret Created by cert-manager

cert-manager automatically creates a Secret with the following structure:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mailinabox-tls
  namespace: default
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-certificate>
  tls.key: <base64-encoded-private-key>
  ca.crt: <base64-encoded-ca-certificate>  # Optional
```

**Secret keys:**

- `tls.crt`: The TLS certificate (public key)
- `tls.key`: The TLS private key
- `ca.crt`: Certificate Authority certificate (if provided)

### 3. Secret Referenced in Ingress

The Ingress resource references the secret for TLS termination:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
spec:
  tls:
    - hosts:
        - box.example.com
      secretName: mailinabox-tls  # Same secret name
```

**Purpose:** The ingress controller uses this secret for TLS termination at the ingress level.

### 4. Secret Mounted in mailinabox Pod

The same secret is mounted as volumes in the mailinabox deployment:

```yaml
volumes:
  - name: tls-cert
    secret:
      secretName: mailinabox-tls  # Same secret
      items:
        - key: tls.crt
          path: tls.crt
  - name: tls-key
    secret:
      secretName: mailinabox-tls  # Same secret
      items:
        - key: tls.key
          path: tls.key
```

**Why two volumes?** We mount the same secret twice with different `items` to extract specific keys.

### 5. Volume Mounts in Container

The volumes are mounted at specific paths in the container:

```yaml
volumeMounts:
  - name: tls-cert
    mountPath: /etc/ssl/certs/tls.crt
    subPath: tls.crt
    readOnly: true
  - name: tls-key
    mountPath: /etc/ssl/private/tls.key
    subPath: tls.key
    readOnly: true
```

**Mount paths:**

- Certificate: `/etc/ssl/certs/tls.crt`
- Private key: `/etc/ssl/private/tls.key`

**Why subPath?**

- The secret contains multiple keys (`tls.crt`, `tls.key`, `ca.crt`)
- Using `subPath` allows us to mount a specific key as a file at a specific path
- Without `subPath`, the entire secret directory would be mounted

### 6. Environment Variables Point to Certificates

Environment variables tell mailinabox where to find the certificates:

```yaml
env:
  - name: SSL_CERTIFICATE
    value: "/etc/ssl/certs/tls.crt"
  - name: SSL_KEY
    value: "/etc/ssl/private/tls.key"
```

**Usage:** Mailinabox services (Postfix, Dovecot) read these environment variables to locate the certificate files.

## Complete Example

Here's the complete flow in the Helm chart:

### certificate.yaml

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
spec:
  secretName: mailinabox-tls  # Secret name
  issuerRef:
    name: letsencrypt-prod
```

### ingress.yaml

```yaml
spec:
  tls:
    - secretName: mailinabox-tls  # References the secret
      hosts:
        - box.example.com
```

### mailinabox-deployment.yaml

```yaml
volumes:
  - name: tls-cert
    secret:
      secretName: mailinabox-tls  # Same secret
      items:
        - key: tls.crt
          path: tls.crt
  - name: tls-key
    secret:
      secretName: mailinabox-tls  # Same secret
      items:
        - key: tls.key
          path: tls.key

volumeMounts:
  - name: tls-cert
    mountPath: /etc/ssl/certs/tls.crt
    subPath: tls.crt
  - name: tls-key
    mountPath: /etc/ssl/private/tls.key
    subPath: tls.key

env:
  - name: SSL_CERTIFICATE
    value: "/etc/ssl/certs/tls.crt"
  - name: SSL_KEY
    value: "/etc/ssl/private/tls.key"
```

## Key Points

1. **Single Source of Truth**: The cert-manager Certificate resource is the source
2. **Automatic Secret Creation**: cert-manager creates the Secret automatically
3. **Dual Usage**: The same secret is used by both:
   - Ingress controller (for TLS termination)
   - mailinabox pod (for Postfix/Dovecot TLS)
4. **Automatic Renewal**: cert-manager automatically renews certificates before expiration
5. **Secret Updates**: When cert-manager renews the certificate, it updates the Secret, and Kubernetes automatically updates the mounted volumes in the pod

## Verification

To verify the certificates are mounted correctly:

```bash
# Check if the secret exists
kubectl get secret mailinabox-tls

# Check certificate in the pod
kubectl exec -it mailinabox-pod -- ls -la /etc/ssl/certs/tls.crt
kubectl exec -it mailinabox-pod -- ls -la /etc/ssl/private/tls.key

# View certificate details
kubectl exec -it mailinabox-pod -- openssl x509 -in /etc/ssl/certs/tls.crt -text -noout
```

## Troubleshooting

### Certificate not mounted?

1. Check if the Certificate resource exists: `kubectl get certificate`
2. Check Certificate status: `kubectl describe certificate mailinabox-tls`
3. Check if Secret was created: `kubectl get secret mailinabox-tls`
4. Check pod volumes: `kubectl describe pod mailinabox-pod`

### Certificate not updating?

- cert-manager updates the Secret automatically
- Kubernetes updates mounted secrets automatically (may take a few seconds)
- Pods don't need to restart for secret updates

### Permission issues?

- Ensure the secret is readable by the pod's service account
- Check file permissions in the container (should be readable by mailinabox user)
