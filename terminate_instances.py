
import os

import click
from connect import vpn_instance_ips
from manage import destroy_instances

@click.command()
@click.option("--aws-profile", default=None, help="AWS profile name to use")
@click.option("--region", default="eu-central-1", help="AWS region to use")
@click.option("--tf-dir", default=".", help="Path to root of private-vpn repository")
def terminate_vpn_instances(aws_profile, region, tf_dir):
    """
    Lists all running VPN instances and asks for confirmation to terminate them.
    """
    running_instances = vpn_instance_ips(region=region, aws_profile=aws_profile)

    if not running_instances:
        print("No running VPN instances found.")
        return

    print("Running VPN instances:")
    for ip in running_instances:
        print(f"- {ip}")

    if click.confirm("Do you want to terminate all running VPN instances?"):
        print("Terminating all running VPN instances...")
        os.chdir(tf_dir)
        destroy_instances()
        print("All running VPN instances have been terminated.")
    else:
        print("Termination canceled.")

if __name__ == "__main__":
    terminate_vpn_instances()
