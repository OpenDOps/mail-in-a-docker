# Contributing Guidelines

## Commit Message Guidelines

When making commits, please follow these guidelines:

### Required Updates

**If you add, remove, or update any dependencies**, you **MUST** update [DEPENDENCIES.md](DEPENDENCIES.md) in the same commit. This includes:

- Alpine `apk` packages in any Dockerfile
- Python `pip` packages in `requirements.txt` or `requirements-system.txt`
- Version changes to existing dependencies

### Commit Message Format

Use the following format:

```text
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `security`

**Scope**: Optional (e.g., `docker`, `nginx`, `dns`, `deps`)

**Subject**:

- Use imperative mood ("add" not "added")
- First letter lowercase
- No period
- Max 72 characters

### Examples

**Good commit message:**

```text
chore(deps): update libtool to 2.4.7-r3

Update libtool version to fix build errors.

- Update DEPENDENCIES.md with new libtool version
```

**Good commit message:**

```text
feat(nginx): add PHP 8.2 support

Add PHP 8.2 packages to nginx container with version pinning.

- Update DEPENDENCIES.md with PHP 8.2 packages
```

**Bad commit message:**

```text
Updated some packages
```

### Dependency Changes Checklist

When changing dependencies, ensure you:

- [ ] Update the Dockerfile(s) with new versions
- [ ] Update `requirements.txt` or `requirements-system.txt` if Python packages changed
- [ ] **Update [DEPENDENCIES.md](DEPENDENCIES.md)** with the changes
- [ ] Test the build locally
- [ ] Verify all containers build successfully
- [ ] Include "Update DEPENDENCIES.md" in your commit message

## Version Pinning

All dependencies must be pinned to exact versions for security. See [SECURITY.md](SECURITY.md) for details.

## Pre-commit Hooks

This project uses pre-commit hooks to ensure code quality. See `README-PRE-COMMIT.md` for detailed setup and usage instructions. Run:

```bash
./.pre-commit-setup.sh
pre-commit install
```

The hooks will automatically check:

- Dockerfile linting (hadolint)
- Shell script linting (shellcheck)
- Python linting (ruff)
- YAML/JSON validation
- Helm chart linting

Running `pre-commit` locally before committing helps keep the codebase **clean, consistent, and safer by catching issues early**.
**All commits are expected to pass the pre-commit checks**, and **pull requests that do not pass pre-commit linting will not be accepted**.

## Testing

Before submitting changes:

1. Run pre-commit hooks: `pre-commit run --all-files`
2. Build all Docker images: `docker compose build`
3. Test the containers: `docker compose up`
4. Verify functionality
