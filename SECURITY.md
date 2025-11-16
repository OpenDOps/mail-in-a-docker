# Security Policy

## Version Pinning and Supply Chain Security

This project implements **strict version pinning** for all dependencies to mitigate supply chain attack risks. All Docker images, system packages, and Python packages use exact version specifications.

### Why Version Pinning?

Supply chain attacks occur when malicious code is introduced through dependencies. By pinning exact versions:

- **Reproducibility**: Every build uses identical dependencies
- **Predictability**: No unexpected changes from upstream updates
- **Security**: Reduced exposure to vulnerabilities in newer, untested versions
- **Auditability**: Clear record of what versions are in use

### Implementation

#### Base Images

All base images are pinned to specific versions:

```dockerfile
FROM alpine:3.20
```

**Note**: For maximum security, consider using image digests:

```dockerfile
FROM alpine:3.20@sha256:<digest>
```

#### System Packages (Alpine `apk`)

All Alpine packages are pinned to exact versions:

```dockerfile
RUN apk add --no-cache \
    bash=5.2.26-r0 \
    curl=8.14.1-r2 \
    ...
```

#### Python Packages (`pip`)

All Python packages are pinned in `requirements.txt` and `requirements-system.txt`:

```dockerfile
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt
```

### Updating Versions

When updating dependencies:

1. **Check Security Advisories**: Review CVE databases and security bulletins
2. **Test Thoroughly**: Update versions in a test environment first
3. **Update Requirements Files**: Modify `requirements.txt` or `requirements-system.txt`
4. **Update Dockerfiles**: Update `apk add` commands with new versions
5. **Verify Builds**: Ensure all Docker images build successfully
6. **Document Changes**: Update version numbers and changelog

### Version Extraction

To extract current package versions from Alpine:

```bash
docker run --rm alpine:3.20 sh -c "apk update && apk info <package> | head -1"
```

Or use the provided script:

```bash
./scripts/get-alpine-versions.sh <package1> <package2> ...
```

### Security Best Practices

1. **Regular Updates**: Review and update dependencies regularly for security patches
2. **Automated Scanning**: Use tools like `trivy`, `snyk`, or `docker scout` to scan images
3. **Minimal Base Images**: Use Alpine Linux for smaller attack surface
4. **No-Cache Installs**: Use `--no-cache-dir` for pip and `--no-cache` for apk
5. **Multi-stage Builds**: Minimize final image size and attack surface
6. **Least Privilege**: Run containers with non-root users where possible

### Reporting Security Issues

If you discover a security vulnerability:

1. **Do NOT** open a public issue
2. Email security details to: kuprin.alexander@gmail.com
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if available)

### Security Scanning

Recommended tools for scanning Docker images:

- **Trivy**: `trivy image <image-name>`
- **Docker Scout**: `docker scout cves <image-name>`
- **Snyk**: `snyk container test <image-name>`

Run scans regularly and before deploying to production.

### Dependency Management

- **Python**: All packages in `requirements.txt` and `requirements-system.txt`
- **Alpine**: All packages pinned in Dockerfiles
- **Base Images**: Pinned to specific Alpine version (consider digests for maximum security)

### Compliance

This version pinning approach helps with:

- **SOC 2**: Change management and security controls
- **ISO 27001**: Information security management
- **PCI DSS**: Secure software development lifecycle
- **NIST**: Supply chain risk management

---

**Last Updated**: 2025-10
