import copy
import json
import os
import shutil
import subprocess
import sys

import click
import yaml

CONFIG_YAML_PATH = "config.yaml"
VAR_FILE_PATH = ".terraform.tfvars.json"
SECRET_STR = "<SECRET_HIDDEN>"


def print_yml_config(yml_obj: dict):
    yml_obj_show = copy.deepcopy(yml_obj)
    yml_obj_show["wg_server_private_key"] = SECRET_STR
    for client in yml_obj_show.get("wg_clients", []):
        if "private_key" in client:
            client["private_key"] = SECRET_STR
        if "preshared_key" in client:
            client["preshared_key"] = SECRET_STR

    print("Found config:")
    yaml.dump(yml_obj_show, sys.stdout, default_flow_style=False)


# Excepts yaml and json files.
def load_config(cfg_path, print_config, ask_confirmation):
    if cfg_path == "stdin":
        stdin_content = sys.stdin.read()
        if stdin_content == "":
            raise ValueError("stdin is empty")

        obj = yaml.safe_load(stdin_content)
        if obj is None or isinstance(obj, str):
            obj = json.loads(stdin_content)

    elif isinstance(cfg_path, str):
        with open(cfg_path, "r") as f:
            obj = yaml.safe_load(f)
    else:
        raise ValueError("Invalid cfg_path type")

    if print_config:
        print_yml_config(obj)

    if ask_confirmation:
        read_input = input("Continue? (y/n): ")
        if read_input != "y":
            sys.exit(1)

    return obj


def update_terraform_tfvars(config):
    with open(VAR_FILE_PATH, "w") as f:
        json.dump(config, f, indent=2)


def run_terraform(action, *args):
    try:
        res = subprocess.run(
            ["terraform", action, *args], text=True, capture_output=True, check=True
        )
    except subprocess.CalledProcessError as e:
        raise ValueError(f"Failed to run terraform command:\n{e.stderr}")

    print(res.stdout)


def rm_generated_files():
    print("About to delete generated files and directories...")
    shutil.rmtree("generated", ignore_errors=True)
    try:
        os.remove("generated_main.tf")
    except FileNotFoundError:
        pass


def generate_modules(clean):
    if os.path.exists("generated") and clean:
        destroy_instances()
        rm_generated_files()

    # First time to generate terraform modules.
    run_terraform("apply", f"-var-file={VAR_FILE_PATH}", "-auto-approve")
    # Init the modules.
    run_terraform("init", "-upgrade")


def destroy_instances():
    run_terraform("destroy", f"-var-file={VAR_FILE_PATH}", "-auto-approve")


@click.group(
    help="Run this command in case you mess up the state and want to delete all resources"
)
def cli():
    pass


@cli.command()
@click.option(
    "--config",
    default=CONFIG_YAML_PATH,
    help=f"Config file path (default: {CONFIG_YAML_PATH})",
)
@click.option(
    "--print-config/--no-print-config",
    default=True,
    help="Print or don't print the config",
)
@click.option(
    "--ask/--no-ask",
    default=True,
    help="Ask to continue or don't ask",
)
def rm_state(config, print_config, ask):
    instances = load_config(config, print_config, ask)["instances"]

    rm_generated_files()

    with open("rm_state.tf", "w") as f:
        for zone, _ in instances.items():
            zone_alias = zone.replace("-", "_")
            region = zone[:-1]

            os.makedirs(f"rm_state/{zone_alias}")

            f.write(f"""
            module "aws_{zone_alias}" {{
                source = "./rm_state/{zone_alias}" 
            }}
            """)

            with open(f"rm_state/{zone_alias}/main.tf", "w") as f2:
                f2.write(f"""
                provider "aws" {{
                    alias = "{zone_alias}"
                    region = "{region}"
                }}
                """)

    run_terraform("init", "-upgrade")
    destroy_instances()

    shutil.rmtree("rm_state", ignore_errors=True)
    os.remove("rm_state.tf")


@cli.command()
def destroy():
    destroy_instances()
    shutil.rmtree("generated", ignore_errors=True)


@cli.command()
@click.option(
    "--config",
    default=CONFIG_YAML_PATH,
    help=f"Config file path (default: {CONFIG_YAML_PATH})",
)
def gen(config):
    cfg = load_config(config, print_config=True, ask_confirmation=True)
    update_terraform_tfvars(cfg)

    clean = False
    if os.path.exists("generated"):
        res = input("The generated directory already exists. Delete it? (y/n)")
        if res == "y":
            clean = True

    generate_modules(clean)


@cli.command()
@click.option(
    "--config",
    default=CONFIG_YAML_PATH,
    help=f"Config file path (default: {CONFIG_YAML_PATH})",
)
@click.option(
    "--print-config/--no-print-config",
    default=True,
    help="Print or don't print the config",
)
@click.option(
    "--ask/--no-ask",
    default=True,
    help="Ask to continue or don't ask",
)
def apply(config, print_config, ask):
    update_terraform_tfvars(load_config(config, print_config, ask))

    # Generate the modules.
    generate_modules(clean=False)

    # Apply the modules.
    run_terraform("apply", f"-var-file={VAR_FILE_PATH}", "-auto-approve")


@cli.command()
@click.option(
    "--config",
    default=CONFIG_YAML_PATH,
    help=f"Config file path (default: {CONFIG_YAML_PATH})",
)
def init_config(config):
    cfg = load_config(config, print_config=True, ask_confirmation=False)
    update_terraform_tfvars(cfg)
    print(VAR_FILE_PATH + " has been updated.")


if __name__ == "__main__":
    cli()
