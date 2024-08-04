# Private VPN Setup

This project automates the setup of a private VPN using Terraform. It provides a command-line interface through `manage.py` to simplify the creation, configuration, and management of the VPN infrastructure.

## Overview

The system uses Terraform to provision the necessary resources on a cloud provider (likely AWS, given the module names). A `manage.py` script acts as a wrapper around Terraform commands to provide a more user-friendly experience.

## Prerequisites

- Python 3
- `click` and `pyyaml` Python libraries (`pip install click pyyaml`)
- Terraform installed and configured with your cloud provider credentials.

## Configuration

Configuration is managed through a `config.yaml` file. You can create your own `config.yaml` by copying the `config_example.yaml`. This file defines the instances, clients, and other variables for your VPN setup.

The script `manage.py` reads `config.yaml` and generates a `.terraform.tfvars.json` file, which is then used by Terraform.

## Usage

The `manage.py` script is the main entry point for managing the VPN infrastructure.

### `init-config`

Initializes the configuration. It reads the specified `--config` file (defaulting to `config.yaml`) and creates/updates the `.terraform.tfvars.json` file.

```bash
python manage.py init-config
```

### `gen`

Generates the necessary Terraform modules based on the configuration.

```bash
python manage.py gen
```

If the `generated` directory already exists, it will prompt you to delete it and start fresh.

### `apply`

Creates or updates the infrastructure. It first loads the configuration, generates the modules (if they don't exist), and then runs `terraform apply`.

```bash
python manage.py apply
```

You can specify a different config file:

```bash
python manage.py apply --config my_custom_config.yaml
```

### `destroy`

Destroys all the resources created by Terraform.

```bash
python manage.py destroy
```

### `rm-state`

This is a utility to help clean up resources if the Terraform state gets corrupted. It generates a temporary Terraform configuration to remove the resources and then cleans up after itself.

```bash
python manage.py rm-state
```

## Accessing the WireGuard UI

Once the VPN is deployed, you can access the WireGuard Easy UI to manage clients and download configuration files. The UI is available at `http://<your_instance_ip>:51821`.

- **Username**: admin
- **Password**: The password you set in your `config.yaml` (`wg_easy_password_hash`).

From the UI, you can add, remove, and manage client configurations. To connect a new device, create a new client and download the corresponding configuration file.

## Terraform Structure

- **`aws_vpn_instance_module`**: Manages the main VPN instance.
- **`aws_vpn_network_module`**: Manages the network resources (VPC, subnets, etc.).
- **`aws_vpn_proxy_module`**: Manages a proxy instance.
- **`templates`**: Contains templates for provisioning scripts.
- **`generated`**: This directory is created by the `gen` command and contains the generated Terraform modules for each instance. It should not be manually edited.

## Manual WireGuard Configuration

For clients that need manual configuration, you can create a file at `/etc/wireguard/work.conf` with the following format. The values in `<>` should be replaced with the corresponding values from your `config.yaml` and your deployed instance's IP address.

```
[Interface]
PrivateKey = <your_client_private_key>
Address = 10.1.1.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = <server_public_key>
PresharedKey = <client_preshared_key_from_config.yaml>
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 0
Endpoint = <instance_public_ip>:51820
```

**Variable Mapping:**

- `<your_client_private_key>`: The `private_key` for the specific client from the `wg_clients` list in your `config.yaml`.
- `<server_public_key>`: The public key of the WireGuard server. This is generated during the server setup. You can retrieve it from the WireGuard Easy UI.
- `<client_preshared_key_from_config.yaml>`: The `preshared_key` for the specific client from the `wg_clients` list in your `config.yaml`.
- `<instance_public_ip>`: The public IP address of your deployed VPN instance.

## Running `vpn_worker.py` on macOS

The `vpn_worker.py` script dynamically checks when new VPN VMs are updated (when spot VMs get replaced and thus get a new IP on creation) and then updates config file provided to it to match a new endpoint ip.
You can run the `vpn_worker.py` script periodically on macOS using `launchd`. Here is an example of a `launchd` configuration file that runs the script every 20 seconds as root.

Create a file named `com.privatevpn.worker.plist` with the following content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>Label</key>
        <string>com.privatevpn.worker</string>
        <key>ProgramArguments</key>
        <array>
            <string>$PYTHON_PATH</string>
            <string>$SCRIPT_DIR/vpn_worker.py</string>
            <string>$WIREGUARD_CONFIG_FILE</string>
        </array>
        <key>EnvironmentVariables</key>
          <dict>
              <key>AWS_SHARED_CREDENTIALS_FILE</key>
              <string>$PATH_TO_AWS_CREDS</string>
          </dict>
        <key>RunAtLoad</key>
        <true/>
        <key>StartInterval</key>
        <integer>20</integer>
    </dict>
</plist>
```

To install and start the service, run the following commands:

```bash
sudo -s cp com.privatevpn.worker.plist /Library/LaunchDaemons/
sudo launchctl load /Library/LaunchDaemons/com.privatevpn.worker.plist

To check if the deamon is running and if there are any errors:
```bash
sudo launchctl list | grep com.privatevpn.worker
less /tmp/com.privatevpn.worker.err
```

To unload
```bash
sudo launchctl unload -w /Library/LaunchDaemons/com.privatevpn.worker.plist
```
