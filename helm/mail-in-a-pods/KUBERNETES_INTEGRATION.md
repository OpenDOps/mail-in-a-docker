# Kubernetes Integration - Ingress Resource Generation

## Current Status

The Helm chart has been updated to:

- ✅ Remove nginx-config PVC (not needed in Kubernetes)
- ✅ Set `IN_KUBERNETES=true` environment variable
- ✅ Skip nginx config file generation when in Kubernetes mode
- ✅ Provide static Ingress resource for primary hostname

## Future Enhancement: Dynamic Ingress Generation

The mailinabox management daemon should be modified to generate Ingress resources dynamically instead of nginx configs when running in Kubernetes.

### Required Changes to `web_update.py`

1. **Detect Kubernetes mode**:

   ```python
   if env.get('IN_KUBERNETES', 'false') == 'true':
       # Generate Ingress resources instead of nginx configs
   ```

2. **Use Kubernetes Python client**:

   ```python
   from kubernetes import client, config
   config.load_incluster_config()  # When running in pod
   # or config.load_kube_config() for local development
   ```

3. **Generate Ingress resources**:
   - For each domain in `get_web_domains(env)`
   - Create/update Ingress resource with:
     - Hostname
     - TLS configuration (cert-manager annotations)
     - Path rules
     - Backend service (mailinabox service)
     - Annotations for nginx-ingress specific features

4. **Handle SSL certificates**:
   - Use cert-manager annotations: `cert-manager.io/cluster-issuer`
   - Let cert-manager provision certificates automatically
   - No need to manage certificate files manually

### Example Ingress Resource Generation

```python
def generate_ingress_for_domain(domain, env, ssl_certificates):
    ingress = client.V1Ingress(
        metadata=client.V1ObjectMeta(
            name=f"mailinabox-{domain}",
            annotations={
                "cert-manager.io/cluster-issuer": env.get("CERT_MANAGER_ISSUER", "letsencrypt-prod"),
                "nginx.ingress.kubernetes.io/ssl-redirect": "true",
            }
        ),
        spec=client.V1IngressSpec(
            ingress_class_name="nginx",
            tls=[client.V1IngressTLS(
                hosts=[domain],
                secret_name=f"{domain}-tls"
            )],
            rules=[client.V1IngressRule(
                host=domain,
                http=client.V1HTTPIngressRuleValue(
                    paths=[client.V1HTTPIngressPath(
                        path="/",
                        path_type="Prefix",
                        backend=client.V1IngressBackend(
                            service=client.V1IngressServiceBackend(
                                name="mailinabox-mailinabox",
                                port=client.V1ServiceBackendPort(number=10222)
                            )
                        )
                    )]
                )
            )]
        )
    )
    return ingress
```

### Benefits

- **Kubernetes-native**: Uses standard Kubernetes resources
- **Automatic SSL**: cert-manager handles certificate provisioning
- **Dynamic updates**: Ingress resources update automatically when domains change
- **No PVC needed**: No shared volumes required
- **Better observability**: Ingress resources visible in `kubectl get ingress`

### Implementation Steps

1. Add `kubernetes` Python package to mailinabox dependencies
2. Modify `do_web_update()` to check `IN_KUBERNETES`
3. Implement Ingress resource generation logic
4. Add RBAC permissions for mailinabox pod to create/update Ingress resources
5. Test with multiple domains and SSL certificates

### RBAC Requirements

The mailinabox pod needs permissions to manage Ingress resources:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: mailinabox-ingress-manager
rules:
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: mailinabox-ingress-manager
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: mailinabox-ingress-manager
subjects:
- kind: ServiceAccount
  name: mailinabox
  namespace: default
```

This would be added to the Helm chart when implementing dynamic Ingress generation.
