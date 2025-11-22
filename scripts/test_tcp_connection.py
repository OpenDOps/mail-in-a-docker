#!/usr/bin/env python3
"""
Test TCP connection to a given IP address and port.

Usage:
    python3 test_tcp_connection.py <ip> <port>
    python3 test_tcp_connection.py 127.0.0.1 25
    python3 test_tcp_connection.py ::1 993
"""

import argparse
import select
import socket
import sys


def test_connection(ip, port, timeout=1, verify_open=True):
    """
    Test TCP connection to the given IP address and port.

    Args:
        ip: IP address (IPv4 or IPv6)
        port: Port number
        timeout: Connection timeout in seconds (default: 1)
        verify_open: If True, verify connection stays open (default: True)

    Returns:
        tuple: (success: bool, message: str)
    """
    # Determine address family based on IP format
    if ":" in ip:
        # IPv6 address
        address_family = socket.AF_INET6
    else:
        # IPv4 address
        address_family = socket.AF_INET

    s = socket.socket(address_family, socket.SOCK_STREAM)
    s.settimeout(timeout)

    try:
        s.connect((ip, port))

        # Verify the connection stays open (indicates a real service is listening)
        if verify_open:
            # Check if socket is still connected by getting peer address
            # If connection was immediately closed, this might fail or return None
            try:
                # peer_addr = s.getpeername()
                # Also check if we can still send (socket is writable)
                # Use a very short timeout to check socket state
                readable, writable, exceptional = select.select([], [s], [s], 0.1)
                if exceptional:
                    # Socket has an error condition
                    return False, f"Connection to {ip}:{port} has an error condition (port may be filtered)"
                if not writable:
                    # Socket is not writable (unlikely but possible)
                    return False, f"Connection to {ip}:{port} is not writable (port may be filtered)"
            except OSError as e:
                # Connection was closed or has an error
                return (
                    False,
                    f"Connection to {ip}:{port} was closed or has an error: {e} (port may be filtered or not accepting connections)",
                )

        return True, f"Successfully connected to {ip}:{port} (connection is open)"
    except socket.timeout:
        return False, f"Connection to {ip}:{port} timed out after {timeout} seconds"
    except socket.gaierror as e:
        return False, f"DNS/Address resolution failed for {ip}: {e}"
    except ConnectionRefusedError:
        return False, f"Connection to {ip}:{port} refused (port is closed or service not running)"
    except OSError as e:
        # Check for specific error codes
        if e.errno == 111:  # Connection refused
            return False, f"Connection to {ip}:{port} refused (port is closed or service not running)"
        elif e.errno == 113:  # No route to host
            return False, f"No route to host {ip}:{port}"
        elif e.errno == 110:  # Connection timed out
            return False, f"Connection to {ip}:{port} timed out"
        else:
            return False, f"Connection to {ip}:{port} failed: {e} (errno: {e.errno})"
    finally:
        try:
            s.close()
        except Exception:
            pass


def main():
    parser = argparse.ArgumentParser(
        description="Test TCP connection to a given IP address and port",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s 127.0.0.1 25
  %(prog)s ::1 993
  %(prog)s 192.168.1.1 465 --timeout 5
        """,
    )

    parser.add_argument("ip", type=str, help="IP address (IPv4 or IPv6) to connect to")

    parser.add_argument("port", type=int, help="Port number to connect to (1-65535)")

    parser.add_argument("--timeout", type=float, default=1.0, help="Connection timeout in seconds (default: 1.0)")

    parser.add_argument("--quiet", action="store_true", help="Only output exit code (0 for success, 1 for failure)")

    parser.add_argument(
        "--no-verify",
        action="store_true",
        help="Skip verification that connection stays open (faster but less accurate)",
    )

    args = parser.parse_args()

    # Validate port range
    if not (1 <= args.port <= 65535):
        print(f"Error: Port must be between 1 and 65535, got {args.port}", file=sys.stderr)
        sys.exit(1)

    # Test the connection
    success, message = test_connection(args.ip, args.port, args.timeout, verify_open=not args.no_verify)

    if args.quiet:
        # Quiet mode: only exit code
        sys.exit(0 if success else 1)
    else:
        # Normal mode: print message and exit
        print(message)
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
