#!/bin/bash
# Setup script for pre-commit hooks

set -e

echo "Setting up pre-commit hooks..."

# Check if pre-commit is installed
if ! command -v pre-commit &> /dev/null; then
    echo "Installing pre-commit..."

    # Prefer pipx on macOS (handles externally-managed-environment)
    if [[ "$OSTYPE" == "darwin"* ]] && command -v pipx &> /dev/null; then
        echo "Using pipx to install pre-commit (recommended for macOS)..."
        pipx install pre-commit
        # Ensure pipx bin is in PATH
        pipx ensurepath
        # Update PATH for current session
        export PATH="$HOME/.local/bin:$PATH"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: try --user flag first, then suggest pipx
        if command -v pip3 &> /dev/null; then
            echo "Installing pre-commit with --user flag..."
            pip3 install --user pre-commit
            # Add user bin to PATH if not already there
            PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
            export PATH="$HOME/Library/Python/${PYTHON_VERSION}/bin:$PATH"
        else
            echo "Error: pip3 not found."
            echo "Recommended: Install pipx for better isolation:"
            echo "  brew install pipx"
            echo "  pipx install pre-commit"
            exit 1
        fi
    else
        # Linux: try pip3 with --user, or regular pip
        if command -v pip3 &> /dev/null; then
            PIP_CMD="pip3"
        elif command -v pip &> /dev/null; then
            PIP_CMD="pip"
        else
            echo "Error: pip or pip3 not found. Please install Python and pip first."
            echo "  Ubuntu/Debian: apt-get install python3-pip"
            exit 1
        fi
        $PIP_CMD install --user pre-commit
    fi
fi

# Install the git hook scripts
echo "Installing git hooks..."

# Ensure pre-commit is in PATH (especially after pipx install)
if [[ "$OSTYPE" == "darwin"* ]] && command -v pipx &> /dev/null; then
    export PATH="$HOME/.local/bin:$PATH"
    # Also try to source shell config if it exists
    if [ -f "$HOME/.zshrc" ]; then
        source "$HOME/.zshrc" 2>/dev/null || true
    elif [ -f "$HOME/.bash_profile" ]; then
        source "$HOME/.bash_profile" 2>/dev/null || true
    elif [ -f "$HOME/.bashrc" ]; then
        source "$HOME/.bashrc" 2>/dev/null || true
    fi
    # Re-export PATH after sourcing
    export PATH="$HOME/.local/bin:$PATH"
fi

# Check if pre-commit is now available
if ! command -v pre-commit &> /dev/null; then
    echo ""
    echo "⚠️  Warning: pre-commit command not found in PATH."
    echo ""
    echo "The PATH was updated by pipx, but needs to be loaded in your current shell."
    echo ""
    echo "Quick fix (for current session only):"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    echo "Permanent fix (choose one):"
    echo "  1. Restart your terminal"
    echo "  2. Or run: source ~/.zshrc  (or ~/.bash_profile if using bash)"
    echo ""
    echo "After fixing PATH, run: pre-commit install"
    echo ""
    exit 1
fi

pre-commit install

# Install additional dependencies
echo "Installing additional dependencies..."

# Install shellcheck if not available
if ! command -v shellcheck &> /dev/null; then
    echo "Note: shellcheck not found. Install it with:"
    echo "  macOS: brew install shellcheck"
    echo "  Ubuntu/Debian: apt-get install shellcheck"
    echo "  Or use: pip install shellcheck-py"
fi

# Install hadolint if not available
if ! command -v hadolint &> /dev/null; then
    echo "Note: hadolint not found. Install it with:"
    echo "  macOS: brew install hadolint"
    echo "  Or download from: https://github.com/hadolint/hadolint/releases"
fi

# Install helm if not available
if ! command -v helm &> /dev/null; then
    echo "Note: helm not found. Install it with:"
    echo "  macOS: brew install helm"
    echo "  Or see: https://helm.sh/docs/intro/install/"
fi

# Install ruff for Python linting (via pip)
if ! python3 -m ruff --version &> /dev/null 2>&1; then
    echo "Installing ruff for Python linting..."
    if [[ "$OSTYPE" == "darwin"* ]] && command -v pipx &> /dev/null; then
        pipx install ruff
    elif command -v pip3 &> /dev/null; then
        pip3 install --user ruff
    elif command -v pip &> /dev/null; then
        pip install --user ruff
    fi
fi

echo ""
echo "Pre-commit hooks installed successfully!"
echo ""

# Check if pre-commit is in PATH for final verification
if ! command -v pre-commit &> /dev/null; then
    echo "⚠️  Note: pre-commit may not be in your PATH in new terminal sessions."
    echo "   Run this to add it to your current session:"
    echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    echo "   Or restart your terminal to load the updated PATH."
    echo ""
fi

echo "To test the hooks, run:"
echo "  pre-commit run --all-files"
echo ""
echo "To skip hooks for a commit, use:"
echo "  git commit --no-verify"
