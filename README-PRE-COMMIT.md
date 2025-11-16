# Pre-commit Hooks

This repository uses [pre-commit](https://pre-commit.com/) to automatically lint and format code before commits.

## Supported Linters

- **Helm**: `helm lint` for Helm charts
- **Python**: `ruff` for linting and formatting
- **Shell**: `shellcheck` for shell script validation
- **Dockerfiles**: `hadolint` for Dockerfile best practices
- **YAML**: Formatting and validation
- **General**: Trailing whitespace, end-of-file fixes, merge conflict detection

## Setup

### Quick Setup

Run the setup script:

```bash
./.pre-commit-setup.sh
```

### Manual Setup

#### 1. Install pre-commit

**Recommended for macOS:**

```bash
# Install pipx (if not already installed)
brew install pipx
pipx ensurepath

# Install pre-commit using pipx (isolated environment)
pipx install pre-commit
```

**Alternative for macOS (if pipx not available):**

```bash
pip3 install --user pre-commit
# Add to PATH (add to ~/.zshrc or ~/.bash_profile)
export PATH="$HOME/Library/Python/$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')/bin:$PATH"
```

**For Linux:**

```bash
pip3 install --user pre-commit
# Add to PATH (add to ~/.bashrc)
export PATH="$HOME/.local/bin:$PATH"
```

#### 2. Install the git hooks

```bash
pre-commit install
```

#### 3. Install additional tools (if not already installed)

```bash
# macOS
brew install shellcheck hadolint helm
# Install ruff (prefer pipx, or use --user)
pipx install ruff
# or
pip3 install --user ruff

# Ubuntu/Debian
apt-get install shellcheck
# Download hadolint from: https://github.com/hadolint/hadolint/releases
# Install helm: https://helm.sh/docs/intro/install/
pip3 install --user ruff
```

## Usage

### Automatic (on commit)

Hooks run automatically when you commit. If any hook fails, the commit is blocked.

### Manual

Run all hooks on all files:

```bash
pre-commit run --all-files
```

Run a specific hook:

```bash
pre-commit run <hook-id> --all-files
```

### Skip hooks (not recommended)

To skip hooks for a specific commit:

```bash
git commit --no-verify
```

## Configuration

- `.pre-commit-config.yaml`: Main configuration file
- `pyproject.toml`: Python/ruff specific settings

## Troubleshooting

### Hook fails but code looks fine

1. Run the hook manually to see detailed output:

   ```bash
   pre-commit run <hook-id> --all-files
   ```

2. Some hooks auto-fix issues. Run with `--all-files` to apply fixes:

   ```bash
   pre-commit run --all-files
   ```

### Hook not running

1. Verify hooks are installed:

   ```bash
   pre-commit run --all-files
   ```

2. Reinstall hooks:

   ```bash
   pre-commit uninstall
   pre-commit install
   ```

### Missing tools

The setup script will warn about missing tools. Install them using the commands shown in the script output.
