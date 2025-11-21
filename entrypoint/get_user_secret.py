#!/usr/local/lib/mailinabox/env/bin/python3
"""
Daemon task to sync system user from Kubernetes secret to SQLite database.
Gets USER_NAME and USER_PASSWORD from a Kubernetes secret and ensures
the system user in the database matches the secret values.
"""

import base64
import os
import sqlite3
import subprocess
import sys

try:
    from kubernetes import client, config
except ImportError:
    print("Error: kubernetes Python client library is required.", file=sys.stderr)
    print("Install it with: pip install kubernetes", file=sys.stderr)
    sys.exit(1)


def get_secret_data(secret_name, namespace):
    """
    Retrieve secret data from Kubernetes.

    Args:
        secret_name: Name of the Kubernetes secret
        namespace: Namespace where the secret exists

    Returns:
        Dictionary with decoded secret data
    """
    try:
        # Try to load in-cluster config first (when running in a pod)
        try:
            config.load_incluster_config()
        except config.ConfigException:
            # Fall back to kubeconfig (for local development)
            config.load_kube_config()

        v1 = client.CoreV1Api()
        secret = v1.read_namespaced_secret(name=secret_name, namespace=namespace)

        # Decode base64 encoded values
        decoded_data = {}
        if secret.data:
            for key, value in secret.data.items():
                decoded_data[key] = base64.b64decode(value).decode("utf-8")

        return decoded_data
    except client.rest.ApiException as e:
        print(f"Error retrieving secret '{secret_name}' from namespace '{namespace}': {e}", file=sys.stderr)
        if e.status == 404:
            print(f"Secret '{secret_name}' not found in namespace '{namespace}'", file=sys.stderr)
        elif e.status == 403:
            print(f"Permission denied accessing secret '{secret_name}'", file=sys.stderr)
        raise
    except Exception as e:
        print(f"Unexpected error retrieving secret: {e}", file=sys.stderr)
        raise


def hash_password(password):
    """
    Hash a password using Dovecot's SHA512-CRYPT scheme.

    Args:
        password: Plain text password

    Returns:
        Hashed password string
    """
    try:
        result = subprocess.run(
            ["/usr/bin/doveadm", "pw", "-s", "SHA512-CRYPT", "-p", password], capture_output=True, text=True, check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error hashing password: {e}", file=sys.stderr)
        raise
    except FileNotFoundError:
        print("Error: doveadm command not found", file=sys.stderr)
        raise


def get_system_user(db_path):
    """
    Get the first system user from the database.

    Args:
        db_path: Path to the SQLite database

    Returns:
        Tuple of (email, password_hash) or (None, None) if not found
    """
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        cursor.execute("SELECT email, password FROM users WHERE is_system = TRUE LIMIT 1")
        row = cursor.fetchone()
        conn.close()

        if row:
            return (row["email"], row["password"])
        return (None, None)
    except sqlite3.Error as e:
        print(f"Error querying database: {e}", file=sys.stderr)
        raise


def create_or_update_system_user(db_path, email, password_hash):
    """
    Create or update the system user in the database.

    Args:
        db_path: Path to the SQLite database
        email: User email address
        password_hash: Hashed password
    """
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Check if user exists
        cursor.execute("SELECT id FROM users WHERE email = ?", (email,))
        existing = cursor.fetchone()

        if existing:
            # Update existing user
            cursor.execute("UPDATE users SET password = ?, is_system = TRUE WHERE email = ?", (password_hash, email))
            print(f"Updated system user: {email}")
        else:
            # Create new system user
            cursor.execute(
                """INSERT INTO users (email, password, privileges, quota, is_system)
                   VALUES (?, ?, 'admin', '0', TRUE)""",
                (email, password_hash),
            )
            print(f"Created system user: {email}")

        conn.commit()
        conn.close()
    except sqlite3.Error as e:
        print(f"Error updating database: {e}", file=sys.stderr)
        raise


def main():
    # Read environment variables
    secret_name = os.environ.get("SECRET_NAME")
    namespace = os.environ.get("NAMESPACE")
    storage_root = os.environ.get("STORAGE_ROOT")

    if not secret_name:
        print("Error: SECRET_NAME environment variable is required", file=sys.stderr)
        sys.exit(1)

    if not namespace:
        print("Error: NAMESPACE environment variable is required", file=sys.stderr)
        sys.exit(1)

    if not storage_root:
        print("Error: STORAGE_ROOT environment variable is required", file=sys.stderr)
        sys.exit(1)

    db_path = os.path.join(storage_root, "mail", "users.sqlite")

    # Check if database exists
    if not os.path.exists(db_path):
        print(f"Error: Database not found at {db_path}", file=sys.stderr)
        sys.exit(1)

    try:
        # Get secret data from Kubernetes
        secret_data = get_secret_data(secret_name, namespace)

        # Extract USER_NAME and USER_PASSWORD
        user_name = secret_data.get("USER_NAME") or secret_data.get("user_name") or secret_data.get("username")
        user_password = (
            secret_data.get("USER_PASSWORD") or secret_data.get("user_password") or secret_data.get("password")
        )

        if not user_name:
            print("Error: USER_NAME (or user_name/username) not found in secret", file=sys.stderr)
            sys.exit(1)

        if not user_password:
            print("Error: USER_PASSWORD (or user_password/password) not found in secret", file=sys.stderr)
            sys.exit(1)

        # Get current system user from database
        db_email, db_password = get_system_user(db_path)

        # Hash the password from secret
        password_hash = hash_password(user_password)

        # Check if update is needed
        needs_update = False

        if not db_email:
            # No system user exists
            print("No system user found in database, creating one...")
            needs_update = True
        elif db_email != user_name:
            # Email doesn't match
            print(f"System user email mismatch: DB has '{db_email}', secret has '{user_name}'")
            needs_update = True
        elif db_password != password_hash:
            # Password doesn't match
            print("System user password mismatch, updating...")
            needs_update = True

        if needs_update:
            create_or_update_system_user(db_path, user_name, password_hash)
            print("System user synchronized successfully")
        else:
            print("System user is already in sync")

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
