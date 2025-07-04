import argparse
import os
import random
import re
import subprocess
import time

import boto3
import botocore

from manage import apply_func


def vpn_instance_ips(region=None, aws_profile=None):
    """
    Lists all EC2 instances with a 'Name' tag starting with 'vpn-instance-'.
    Loads credentials from OS keychain if available, otherwise uses default boto3 resolution.
    """
    try:
        session_kwargs = {"region_name": region}
        # Try to load credentials from keyring
        # access_key = keyring.get_password("aws", "access_key")
        # secret_key = keyring.get_password("aws", "secret_key")
        # if access_key and secret_key:
        #     print("Using AWS credentials from keyring.")
        #     session_kwargs["aws_access_key_id"] = access_key
        #     session_kwargs["aws_secret_access_key"] = secret_key
        if aws_profile:
            print(f"Using AWS profile: {aws_profile}")
            session_kwargs["profile_name"] = aws_profile

        session = boto3.Session(**session_kwargs)
        ec2 = session.client("ec2")
        paginator = ec2.get_paginator("describe_instances")
        pages = paginator.paginate(
            Filters=[{"Name": "tag:Name", "Values": ["vpn-instance-*"]}]
        )

        ips = []
        for page in pages:
            for reservation in page["Reservations"]:
                for instance in reservation["Instances"]:
                    state = instance["State"]["Name"]
                    public_ip = instance.get("PublicIpAddress")

                    if state == "running" and public_ip:
                        ips.append(public_ip)

    except botocore.exceptions.NoCredentialsError as e:
        print(f"Error: AWS credentials not found: {e}")
        print("Please configure your credentials (e.g., via `aws configure`).")
        return []
    except botocore.exceptions.ClientError as e:
        print(f"An AWS client error occurred: {e}")
        return []

    return ips


def is_vpn_established():
    res = subprocess.run(
        ["wg", "show", "interfaces"], capture_output=True, text=True, check=True
    )
    return res.stdout.strip() != ""


def update_wireguard_config(config_path, vpn_profile, available_ips, up):
    """
    Parses a WireGuard config file and updates endpoint IPs if they are not in the available list.
    """
    try:
        with open(config_path, "r") as f:
            config_content = f.read()
    except FileNotFoundError:
        print(f"Error: The file '{config_path}' was not found.")
        return

    endpoints = re.findall(r"Endpoint = (.*):(\d+)", config_content)
    if not endpoints:
        print(f"No 'Endpoint' entries found in {config_path}.")
        return

    if not available_ips:
        print("No available VPN IPs from AWS. Cannot update config.")
        return

    config_changed = False
    for ip, port in endpoints:
        if ip not in available_ips:
            new_ip = random.choice(available_ips)
            print(
                f"Endpoint {ip}:{port} is not in the available IP list. Updating to {new_ip}:{port}."
            )
            old_endpoint = f"Endpoint = {ip}:{port}"
            new_endpoint = f"Endpoint = {new_ip}:{port}"
            config_content = config_content.replace(old_endpoint, new_endpoint)
            config_changed = True

    if config_changed:
        try:
            with open(config_path, "w") as f:
                f.write(config_content)
            print(f"Successfully updated {config_path}.")
        except IOError as e:
            print(f"Error writing to file {config_path}: {e}")

        try:
            if is_vpn_established():
                # Restart the WireGuard interface to apply changes
                subprocess.run(
                    ["wg-quick", "down", vpn_profile], check=True, capture_output=True
                )
                subprocess.run(
                    ["wg-quick", "up", vpn_profile], check=True, capture_output=True
                )
                return

        except subprocess.CalledProcessError as e:
            print(f"Command failed with error: {e}")
            print(f"Error output: {e.stderr}")

    else:
        print("All endpoints are already up to date.")

    try:
        if up and not is_vpn_established():
            print("Establishing VPN connection...")
            subprocess.run(
                ["wg-quick", "up", vpn_profile], check=True, capture_output=True
            )
            print("VPN connection established.")
            return

    except subprocess.CalledProcessError as e:
        print(f"Command failed with error: {e}")
        print(f"Error output: {e.stderr}")


def main():
    """Runs the worker to fetch VPN instance IPs and update WireGuard config."""
    parser = argparse.ArgumentParser(
        description="Periodically update WireGuard config with available VPN IPs."
    )
    parser.add_argument(
        "config_file",
        help="Path to the WireGuard configuration file (e.g., /etc/wireguard/work.conf)",
    )
    parser.add_argument(
        "--continious",
        action="store_true",
        help="Run the worker in continuous mode, polling for updates every 20 seconds.",
    )
    parser.add_argument(
        "--region",
        default="eu-central-1",
        help="AWS region to use (default: eu-central-1)",
    )
    parser.add_argument(
        "--aws-profile",
        default=None,
        help="AWS profile name to use (optional, falls back to keychain or default resolution)",
    )

    parser.add_argument(
        "--up",
        action="store_true",
        help="Establish VPN connection if not established already",
    )

    parser.add_argument(
        "--vpn-config",
        type=str,
        required=True,
        help="Path to yaml config file with VPN settings",
    )

    parser.add_argument(
        "--tf-dir",
        type=str,
        default=".",
        help="Path to directory where private-vpn is clonned",
    )

    args = parser.parse_args()

    filename_with_extension = os.path.basename(args.config_file)
    vpn_profile = os.path.splitext(filename_with_extension)[0]

    while True:
        print("Querying for VPN instances...")
        available_ips = vpn_instance_ips(
            region=args.region, aws_profile=args.aws_profile
        )

        if available_ips:
            print(f"Found running VPN instances: {available_ips}")
            update_wireguard_config(
                args.config_file, vpn_profile, available_ips, args.up
            )
        elif args.up and args.tf_dir != "":
            print("No running VPN instances found. Spinning up new instances...")
            os.chdir(args.tf_dir)
            apply_func(args.vpn_config, False, False)
            wait_for_vpn_instance(args.region, args.aws_profile)
            continue
        else:
            print("No running VPN instances found. Skipping WireGuard config update.")

        if not args.continious:
            break

        print("Waiting for 20 seconds before the next poll...")
        time.sleep(20)


def wait_for_vpn_instance(region, aws_profile):
    """
    Waits for a VPN instance to become available.
    """
    while True:
        ips = vpn_instance_ips(region=region, aws_profile=aws_profile)
        if ips:
            print("Waiting 90 seconds for a VPN instance to start serving...")
            time.sleep(90)
            return
        print("Waiting for VPN instance to become available...")
        time.sleep(5)


if __name__ == "__main__":
    main()
