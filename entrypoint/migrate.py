#!/usr/bin/python3
"""
Migration script that handles version changes based on MAILINABOX_VERSION.
Reads the previous version from ${STORAGE_ROOT}/mailinabox.version and
if it differs from MAILINABOX_VERSION, runs migration and updates the file.
"""

import os
import sys

sys.path.insert(0, "/opt/MailInABox/management")
from utils import load_environment


def migrate_version(previous_version, new_version, env):
    """
    Handle migration from previous_version to new_version.
    This function can be extended to handle specific version migrations.

    Args:
            previous_version: The previous Mail-in-a-Box version (e.g., "v72")
            new_version: The new Mail-in-a-Box version (e.g., "v73")
            env: Environment dictionary with STORAGE_ROOT, etc.
    """
    print(f"Migrating from {previous_version} to {new_version}")

    if new_version == "kube-v0.1.15" and previous_version != "kube-v0.1.15":
        print("echo 'Migrating from classic v73 to Mail-in-a-Pods (kube-*) version.'")

        # Add "is_system" column to the mail/users.sqlite users table if it doesn't exist

        import sqlite3

        users_db_path = os.path.join(env["STORAGE_ROOT"], "mail/users.sqlite")
        try:
            conn = sqlite3.connect(users_db_path)
            c = conn.cursor()

            c.execute("ALTER TABLE users ADD COLUMN is_system BOOLEAN NOT NULL DEFAULT FALSE;")
            conn.commit()

            conn.close()
        except Exception as e:
            print(f"Error migrating users table to add 'is_system': {e}")
            raise

    # End of migrations


def main():
    # Load environment
    env = load_environment()
    storage_root = env.get("STORAGE_ROOT", "/home/user-data")
    version_file = os.path.join(storage_root, "mailinabox.version")

    # Get current version from environment
    if os.environ.get("IN_KUBERNETES") == "true":
        mailinapods_version = os.environ.get("MAILINAPODS_VERSION")
        if not mailinapods_version:
            print("Error: MAILINAPODS_VERSION environment variable not set")
            raise RuntimeError("MAILINAPODS_VERSION environment variable not set")
        new_version = f"kube-{mailinapods_version}"
    else:
        new_version = os.environ.get("MAILINABOX_VERSION")
    if not new_version:
        print("Warning: MAILINABOX_VERSION environment variable not set")
        # Fallback to getting version from migrate.py --current
        try:
            import subprocess

            result = subprocess.run(
                ["python3", "/opt/MailInABox/setup/migrate.py", "--current"],
                capture_output=True,
                text=True,
                cwd="/opt/MailInABox",
            )
            if result.returncode == 0:
                new_version = f"v{result.stdout.strip()}"
                print(f"Using version from migrate.py --current: {new_version}")
            else:
                print("Error: Could not determine version")
                return 1
        except Exception as e:
            print(f"Error determining version: {e}")
            return 1

    # Read previous version
    previous_version = None
    if os.path.exists(version_file):
        try:
            with open(version_file, encoding="utf-8") as f:
                previous_version = f.read().strip()
        except Exception as e:
            print(f"Warning: Could not read version file: {e}")

    # Check if version changed
    if previous_version != new_version:
        if previous_version is None:
            print(f"No previous version found. Setting version to {new_version}")
        else:
            print(f"Version changed from {previous_version} to {new_version}")
            # Run migration
            migrate_version(previous_version, new_version, env)

        # Write new version to file
        try:
            os.makedirs(os.path.dirname(version_file), exist_ok=True)
            with open(version_file, "w", encoding="utf-8") as f:
                f.write(new_version + "\n")

            # Set proper permissions
            storage_user = env.get("STORAGE_USER", "user-data")
            try:
                import pwd

                uid = pwd.getpwnam(storage_user).pw_uid
                gid = pwd.getpwnam(storage_user).pw_gid
                os.chown(version_file, uid, gid)
            except (KeyError, ImportError):
                # User doesn't exist or pwd module not available, skip chown
                pass

            print(f"Updated {version_file} to version {new_version}")
        except Exception as e:
            print(f"Error writing version file: {e}")
            return 1
    else:
        print(f"Version unchanged: {new_version}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
