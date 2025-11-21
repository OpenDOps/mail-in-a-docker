#!/usr/local/lib/mailinabox/env/bin/python3
"""
Init container script to fetch Gateway LoadBalancer IP addresses.
Waits for Gateway to have IP addresses, or falls back to associated LoadBalancer services.
Exports PUBLIC_IP and PUBLIC_IPV6 as environment variables.
"""

import os
import re
import sys
import time

try:
    from kubernetes import client, config
except ImportError:
    print("Error: kubernetes Python client library is required.", file=sys.stderr)
    print("Install it with: pip install kubernetes", file=sys.stderr)
    sys.exit(1)


def is_ipv4(ip):
    """Check if a string is a valid IPv4 address."""
    pattern = r"^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
    if not re.match(pattern, ip):
        return False
    # Validate each octet is 0-255
    parts = ip.split(".")
    return all(0 <= int(part) <= 255 for part in parts)


def is_ipv6(ip):
    """Check if a string is a valid IPv6 address (contains colons)."""
    return ":" in ip


def get_gateway_addresses(gateway_name, namespace):
    """
    Get IP addresses from Gateway status.

    Args:
        gateway_name: Name of the Gateway
        namespace: Namespace where the Gateway exists

    Returns:
        Tuple of (ipv4, ipv6) or (None, None) if not found
    """
    try:
        v1 = client.CustomObjectsApi()
        gateway = v1.get_namespaced_custom_object(
            group="gateway.networking.k8s.io", version="v1", namespace=namespace, plural="gateways", name=gateway_name
        )

        ipv4 = None
        ipv6 = None

        addresses = gateway.get("status", {}).get("addresses", [])
        if addresses:
            for addr in addresses:
                addr_type = addr.get("type", "")
                addr_value = addr.get("value", "")

                if addr_type == "IPAddress" and addr_value:
                    if is_ipv4(addr_value):
                        ipv4 = addr_value
                    elif is_ipv6(addr_value):
                        ipv6 = addr_value

        return (ipv4, ipv6)
    except client.rest.ApiException as e:
        if e.status == 404:
            return (None, None)
        print(f"Error getting Gateway '{gateway_name}': {e}", file=sys.stderr)
        return (None, None)
    except Exception as e:
        print(f"Unexpected error getting Gateway: {e}", file=sys.stderr)
        return (None, None)


def get_loadbalancer_ips(service_name, namespace):
    """
    Get IP addresses from a LoadBalancer service.

    Args:
        service_name: Name of the Service
        namespace: Namespace where the Service exists

    Returns:
        Tuple of (ipv4, ipv6) or (None, None) if not found
    """
    try:
        v1 = client.CoreV1Api()
        service = v1.read_namespaced_service(name=service_name, namespace=namespace)

        ipv4 = None
        ipv6 = None

        ingress = service.status.load_balancer.ingress or []
        for entry in ingress:
            ip = entry.ip
            if ip:
                if is_ipv4(ip):
                    ipv4 = ip
                elif is_ipv6(ip):
                    ipv6 = ip

        return (ipv4, ipv6)
    except client.rest.ApiException as e:
        if e.status == 404:
            return (None, None)
        print(f"Error getting Service '{service_name}': {e}", file=sys.stderr)
        return (None, None)
    except Exception as e:
        print(f"Unexpected error getting Service: {e}", file=sys.stderr)
        return (None, None)


def find_loadbalancer_services(gateway_name, namespace):
    """
    Find LoadBalancer services associated with the Gateway.

    Args:
        gateway_name: Name of the Gateway
        namespace: Namespace to search in

    Returns:
        List of service names
    """
    try:
        v1 = client.CoreV1Api()

        # Try to find by label selector
        label_selector = f"gateway.networking.k8s.io/gateway-name={gateway_name}"
        services = v1.list_namespaced_service(namespace=namespace, label_selector=label_selector)

        if services.items:
            return [svc.metadata.name for svc in services.items]

        # Fallback: find all LoadBalancer services and check if any match gateway name
        all_services = v1.list_namespaced_service(namespace=namespace, field_selector="spec.type=LoadBalancer")

        matching_services = []
        for svc in all_services.items:
            if gateway_name in svc.metadata.name:
                matching_services.append(svc.metadata.name)

        return matching_services
    except Exception as e:
        print(f"Error finding LoadBalancer services: {e}", file=sys.stderr)
        return []


def export_env_vars(ipv4=None, ipv6=None):
    """
    Export IP addresses as environment variables.
    Sets PUBLIC_IP and PUBLIC_IPV6 in the current process and prints export statements.

    Args:
        ipv4: IPv4 address (optional)
        ipv6: IPv6 address (optional)
    """
    # Set environment variables in current process
    os.environ["PUBLIC_IP"] = ipv4 or ""
    os.environ["PUBLIC_IPV6"] = ipv6 or ""

    # Print export statements so they can be sourced if needed
    print(f'export PUBLIC_IP="{ipv4 or ""}"')
    print(f'export PUBLIC_IPV6="{ipv6 or ""}"')

    print("Environment variables exported successfully")


def main():
    # Read environment variables
    gateway_name = os.environ.get("GATEWAY_NAME")
    namespace = os.environ.get("NAMESPACE")

    if not gateway_name:
        print("Error: GATEWAY_NAME environment variable is required", file=sys.stderr)
        sys.exit(1)

    if not namespace:
        print("Error: NAMESPACE environment variable is required", file=sys.stderr)
        sys.exit(1)

    # Load Kubernetes config
    try:
        try:
            config.load_incluster_config()
        except config.ConfigException:
            config.load_kube_config()
    except Exception as e:
        print(f"Error loading Kubernetes config: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Waiting for Gateway {gateway_name} to have IP addresses...")
    ipv4 = None
    ipv6 = None

    # Try for 20 attempts (1 minute total)
    for attempt in range(1, 21):
        # Get addresses from Gateway status
        print(f"Getting addresses from Gateway {gateway_name} in namespace {namespace}")
        ipv4, ipv6 = get_gateway_addresses(gateway_name, namespace)

        # If Gateway doesn't have addresses, try LoadBalancer services
        if not ipv4 and not ipv6:
            print(f"Gateway {gateway_name} has no addresses in status, checking associated LoadBalancer service...")

            # Find LoadBalancer services
            lb_services = find_loadbalancer_services(gateway_name, namespace)
            print(f"LoadBalancer services found: {lb_services}")

            for svc_name in lb_services:
                print(f"Checking LoadBalancer service: {svc_name}")
                svc_ipv4, svc_ipv6 = get_loadbalancer_ips(svc_name, namespace)

                if svc_ipv4:
                    ipv4 = svc_ipv4
                if svc_ipv6:
                    ipv6 = svc_ipv6

                if ipv4 or ipv6:
                    print(f"Found IPs from LoadBalancer service {svc_name}")
                    break

        # If we have at least one IP, export environment variables and exit
        if ipv4 or ipv6:
            print(f"Gateway IPv4 found: {ipv4 or '<none>'}")
            print(f"Gateway IPv6 found: {ipv6 or '<none>'}")
            export_env_vars(ipv4, ipv6)
            sys.exit(0)

        print(f"Attempt {attempt}/20: Gateway IPs not ready yet, waiting 5 seconds...")
        time.sleep(5)

    # If we get here, no IPs were found after 20 attempts
    print("Warning: Gateway IPs not found after 1 minute, exporting empty values")
    sys.exit(1)


if __name__ == "__main__":
    main()
