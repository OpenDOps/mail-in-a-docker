# Kubernetes Integration - Gateway API Architecture

## Overview

Mail-in-a-Pods uses the **Gateway API** (not the older Ingress API) for all network routing in Kubernetes. This provides a more flexible, extensible, and cloud-native approach to routing HTTP/HTTPS, SMTP, and IMAP traffic.

## Current Architecture

### Core Components

1. **Gateway Resources** - Define network endpoints and listeners
   - HTTP/HTTPS Gateway for web traffic
   - TCP Gateway for SMTP/IMAP traffic
   - Supports Cilium and NGINX Gateway classes

2. **HTTPRoute Resources** - Route HTTP/HTTPS traffic to services
   - Health check route to static server
   - Primary HTTP route for mailinabox service
   - Path-based routing (e.g., `/admin/assets/` to static server)

3. **TCPRoute Resources** - Route SMTP/IMAP traffic
   - SMTP (port 25)
   - IMAP (port 143)
   - IMAPS (port 993)
   - SMTPS (port 465)
   - Submission (port 587)

4. **Certificate Management** - Automated TLS with cert-manager
   - ClusterIssuer for Let's Encrypt certificates
   - Certificate resources for each domain
   - Automatic provisioning and renewal

5. **RBAC Permissions** - Gateway IP fetching
   - ServiceAccount for fetching Gateway LoadBalancer IPs
   - Role with permissions to read Gateways and Services
   - Used by init container to expose Gateway IPs

### Infrastructure Resources

#### Gateway API Resources

**Gateway (HTTP/HTTPS)**
- Listens on HTTP (80) and HTTPS (443) ports
- Supports multiple TLS configurations per hostname
- Health check listener on separate port (optional)
- Annotations for LoadBalancer IP sharing (Cilium)

**Gateway (TCP)**
- Listens on SMTP, IMAP, IMAPS, SMTPS, and Submission ports
- Routes TCP traffic directly to mailinabox service

**HTTPRoute**
- Routes `/admin/assets/` to static placeholder server
- Routes `/` to mailinabox service (or placeholder if enabled)
- Health check route to static server

**TCPRoute**
- Separate routes for each mail protocol
- Routes TCP traffic to mailinabox service on appropriate ports

#### StatefulSet

The mailinabox application runs as a **StatefulSet** (not Deployment) to:
- Support ReadWriteOnce persistent volumes
- Maintain stable network identity
- Handle stateful data properly

#### Services

- **mailinabox Service** - ClusterIP service exposing mailinabox ports
  - HTTP: 10222
  - SMTP: 25
  - IMAP: 143
  - IMAPS: 993
  - SMTPS: 465
  - Submission: 587

- **statics-server Service** - ClusterIP service for static placeholder content

#### Storage

- **PersistentVolumeClaim** - For mailinabox user data
  - ReadWriteOnce access mode
  - Configurable size (default: 50Gi)
  - Uses StorageClass from values or default

#### Certificates

- **ClusterIssuer** - cert-manager issuer for Let's Encrypt
  - HTTP-01 challenge solver
  - Supports staging and production environments

- **Certificate Resources** - One per TLS configuration
  - Automatically provisioned by cert-manager
  - Mounted as secrets into mailinabox pod
  - Auto-renewed before expiration

#### Secrets

- **system-user Secret** - Contains admin user credentials
  - `USER_NAME`: Username (e.g., "admin")
  - `USER_PASSWORD`: Plain text password
  - Synced to SQLite database via daemon service

- **Gateway IP Secret** - Contains LoadBalancer IPs
  - `PUBLIC_IP`: IPv4 address (fetched from Gateway status)
  - `PUBLIC_IPV6`: IPv6 address (if available)
  - Created automatically by init container

### Gateway IP Discovery

The Helm chart automatically fetches Gateway LoadBalancer IP addresses:

1. **Init Container** (`get-gateway-ip`)
   - Runs Python script to query Gateway status
   - Falls back to checking LoadBalancer services
   - Waits up to 1 minute for IPs to be assigned
   - Exports `PUBLIC_IP` and `PUBLIC_IPV6` environment variables

2. **RBAC Permissions**
   - ServiceAccount with permissions to:
     - Read Gateways (gateway.networking.k8s.io)
     - Read Services (for LoadBalancer discovery)
     - Create/update Secrets (for storing IPs)

### System User Synchronization

The system admin user is synchronized from Kubernetes secrets to the SQLite database:

1. **Secret Creation**
   - Created from `mailinabox.systemUserName` and `mailinabox.systemUserPassword` values
   - Contains `USER_NAME` and `USER_PASSWORD` fields

2. **Daemon Service** (`set_system_user`)
   - s6 service that runs `get_user_secret.py` periodically
   - Fetches secret data from Kubernetes
   - Constructs email as `{USER_NAME}@{PRIMARY_HOSTNAME}`
   - Hashes password using Dovecot's SHA512-CRYPT
   - Creates or updates system user in SQLite database

3. **Environment Variables**
   - `SYSTEM_USER_SECRET_NAME`: Name of the secret
   - `NAMESPACE`: Kubernetes namespace
   - `PRIMARY_HOSTNAME`: Primary domain name
   - `STORAGE_ROOT`: Path to user data storage

## Configuration

### Gateway Class Support

The chart supports multiple Gateway API implementations:

- **Cilium** (`gateway.className: "cilium"`)
  - Uses separate Gateways for HTTP and TCP
  - Supports LoadBalancer IP sharing via annotations
  - Requires Cilium CNI with Gateway API support

- **NGINX** (`gateway.className: "nginx"`)
  - Uses single Gateway for all listeners
  - Requires NGINX Gateway Controller

### TLS Configuration

TLS is configured via `gateway.tls` array:

```yaml
gateway:
  tls:
    - hostname: "mail.example.com"
      secretName: "mail-example-com-tls"
```

Each TLS configuration:
- Creates a Certificate resource (if cert-manager is enabled)
- Adds a TLS listener to Gateway
- Mounts certificate secrets into mailinabox pod

### Static Placeholder

A placeholder static server can be enabled while mailinabox is initializing:

```yaml
gateway:
  staticsServer:
    enabled: true
    placeholderEnabled: true  # Route all traffic to placeholder
```

This is useful during initial deployment before mailinabox is fully configured.

## Future Enhancements

### Dynamic HTTPRoute Generation

Currently, HTTPRoute resources are statically defined in Helm templates. Future enhancement could dynamically generate HTTPRoutes:

1. **Modify `web_update.py`** to generate HTTPRoute resources instead of nginx configs when `IN_KUBERNETES=true`
2. **Use Kubernetes Python client** to create/update HTTPRoute resources
3. **Add RBAC permissions** for mailinabox pod to manage HTTPRoute resources

Benefits:
- Dynamic domain management
- Automatic route updates when domains change
- No manual Helm upgrades needed for domain changes

### Required Changes

1. **Add RBAC permissions** for HTTPRoute management:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: mailinabox-httproute-manager
rules:
- apiGroups: ["gateway.networking.k8s.io"]
  resources: ["httproutes"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

2. **Modify `web_update.py`**:

```python
if env.get('IN_KUBERNETES', 'false') == 'true':
    # Generate HTTPRoute resources instead of nginx configs
    from kubernetes import client, config
    config.load_incluster_config()

    for domain in get_web_domains(env):
        generate_httproute_for_domain(domain, env)
```

3. **Example HTTPRoute generation**:

```python
def generate_httproute_for_domain(domain, env):
    httproutes_api = client.CustomObjectsApi()

    httproute = {
        "apiVersion": "gateway.networking.k8s.io/v1",
        "kind": "HTTPRoute",
        "metadata": {
            "name": f"mailinabox-{domain}",
            "namespace": env.get("NAMESPACE", "default")
        },
        "spec": {
            "parentRefs": [{
                "name": env.get("GATEWAY_NAME"),
                "sectionName": "https"
            }],
            "hostnames": [domain],
            "rules": [{
                "backendRefs": [{
                    "name": env.get("MAILINABOX_SERVICE_NAME"),
                    "port": 10222
                }]
            }]
        }
    }

    httproutes_api.create_namespaced_custom_object(
        group="gateway.networking.k8s.io",
        version="v1",
        namespace=env.get("NAMESPACE", "default"),
        plural="httproutes",
        body=httproute
    )
```

## Troubleshooting

### Gateway IP Not Found

If Gateway LoadBalancer IPs are not being discovered:

1. Check init container logs:
   ```bash
   kubectl logs <pod-name> -c get-gateway-ip
   ```

2. Verify RBAC permissions:
   ```bash
   kubectl get rolebinding -n <namespace>
   ```

3. Check Gateway status:
   ```bash
   kubectl get gateway <gateway-name> -o yaml
   ```

### System User Not Syncing

If the system user is not being created/updated:

1. Check daemon service logs:
   ```bash
   kubectl logs <pod-name> -c mailinabox | grep set_system_user
   ```

2. Verify secret exists:
   ```bash
   kubectl get secret <secret-name> -n <namespace>
   ```

3. Check environment variables:
   ```bash
   kubectl describe pod <pod-name> | grep SYSTEM_USER
   ```

### Certificates Not Issued

If TLS certificates are not being issued:

1. Check Certificate status:
   ```bash
   kubectl get certificate -n <namespace>
   kubectl describe certificate <certificate-name>
   ```

2. Verify ClusterIssuer:
   ```bash
   kubectl get clusterissuer
   kubectl describe clusterissuer <issuer-name>
   ```

3. Check cert-manager logs:
   ```bash
   kubectl logs -n cert-manager -l app=cert-manager
   ```

## Additional Resources

- [Gateway API Specification](https://gateway-api.sigs.k8s.io/)
- [Cilium Gateway API](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/)
- [NGINX Gateway Controller](https://github.com/nginxinc/nginx-kubernetes-gateway)
- [cert-manager Documentation](https://cert-manager.io/docs/)
