terraform {
  required_version = "~> 1.9.4"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.1"
    }
  }
}

locals {
  flattened_instances = flatten([
    for zone, instances in var.instances : [
      for instance in instances : merge(instance, { zone_alias = replace(zone, "-", "_") })
    ]
  ])

  instances_with_defaults = [
    for instance in local.flattened_instances : merge(instance, {
      wg_easy_password_hash = replace(coalesce(instance.wg_easy_password_hash, var.wg_easy_password_hash), "$", "$$"),
    })
  ]

  unique_instances = {
    for _, instance in local.instances_with_defaults :
    "${instance.zone_alias}_${instance.name}" => instance
  }

  zones = { for zone, instances in var.instances : replace(zone, "-", "_") => zone }

  region_list = distinct([for zone, instances in var.instances : substr(zone, 0, length(zone) - 1)])
  regions     = { for region in local.region_list : replace(region, "-", "_") => region }

  public_key             = "file(\"$${path.root}/private_vpn_host.pub\")"
  wg_user_data_tmpl_path = "${path.root}/provision/wg_easy.tftpl"

  # proxy_targets = {
  #   for zone, instances in var.instances : replace(zone, "-", "_") => [
  #     for instance in instances : {
  #       prefix = instance.name
  #       host   = instance.private_ip
  #       port   = instance.wg_easy_web_port
  #     }
  #   ]
  # }
}

# Entities that need to be generated per region go here.
resource "local_file" "generate_region_configs" {
  for_each = local.regions

  content = <<EOT
    provider "aws" {
      alias  = "${each.key}"
      region = "${each.value}"
    }

    resource "aws_key_pair" "vpn_ssh_key" {
      provider   = aws.${each.key}
      key_name   = "${var.key_name}"
      public_key = ${local.public_key}
    }
  EOT

  filename = "${path.root}/generated/${each.key}/main.tf"
}

# resource "local_file" "generate_proxy_configs" {
#   for_each = local.proxy_targets

#   content = <<EOT
# module "aws_vpn_proxy_${each.key}" {
#   source   = "../../aws_vpn_proxy_module"
#   key_name          = "${var.key_name}"
#   instance_type     = "t2.nano"
#   vpc_id         = module.aws_vpn_network_${each.key}.vpc_id
#   subnet_id         = module.aws_vpn_network_${each.key}.subnet_id

#   user_data = templatefile("${path.root}/provision/nginx.tftpl", {
#     vm_user         = "ubuntu",

#     nginx_conf_content = templatefile("${path.root}/provision/proxy.conf.tftpl", {
#       nginx_listen_port    = "80",
#       nginx_server_name    = "server-name",
#       nginx_forward_scheme = "http",

#       nginx_proxy_targets   = jsonencode(${jsonencode(each.value)})
# }),
#   })

#   providers = {
#     aws = aws.${each.key}
#   }
# }

# output "aws_proxy_${each.key}_public_ip" {
#   value = module.aws_vpn_proxy_${each.key}.proxy_public_ip
# }

#   EOT

#   filename = "${path.root}/generated/${each.key}/proxy.tf"
# }


# Generate Terraform configuration files for each zone
resource "local_file" "generate_network_configs" {
  for_each = local.zones

  content = <<EOT
provider "aws" {
  alias  = "${each.key}"
  region = "${substr(each.value, 0, length((each.value)) - 1)}"
}

module "aws_vpn_network_${each.key}" {
  source            = "../../aws_vpn_network_module"
  availability_zone = "${each.value}"
  vpc_cidr_block    = "10.0.0.0/16"
  subnet_cidr_block = "10.0.1.0/24"

  providers = {
    aws = aws.${each.key}
  }
}
EOT

  filename = "${path.root}/generated/${each.key}/main.tf"
}

# Generate Terraform configuration files for each instance
resource "local_file" "generate_instance_configs" {
  for_each = local.unique_instances

  content = <<EOT
module "aws_vpn_instance_${each.value.zone_alias}_${each.value.name}" {
  source   = "../../aws_vpn_instance_module"
  instance_type     = "${each.value.instance_type}"
  key_name          = "${var.key_name}"
  user_data         = templatefile("${local.wg_user_data_tmpl_path}", {
    vm_user               = "${each.value.vm_user}"
    wg_easy_password_hash = replace("${each.value.wg_easy_password_hash}", "$$", "\\$\\$")
    wg_vpn_server_address = "${each.value.wg_vpn_server_address}"
    wg_vpn_mask           = "${each.value.wg_vpn_mask}"
    wg_dns                = "${each.value.wg_dns}"
    wg_port               = "${each.value.wg_port}"
    wg_easy_web_port      = "${each.value.wg_easy_web_port}"
    wg_server_private_key = "${var.wg_server_private_key}"
    wg_clients            = jsonencode(${jsonencode(var.wg_clients)})
  })
  instance_name     = "vpn-instance-${each.value.name}"
  subnet_id         = module.aws_vpn_network_${each.value.zone_alias}.subnet_id
  security_group_id = module.aws_vpn_network_${each.value.zone_alias}.security_group_id
  private_ip        = "${each.value.private_ip}"

  providers = {
    aws = aws.${each.value.zone_alias}
  }
}

output "aws_instance_${each.value.name}_public_ip" {
  value = module.aws_vpn_instance_${each.value.zone_alias}_${each.value.name}.vpn_instance_public_ip
}

EOT

  filename = "${path.root}/generated/${each.value.zone_alias}/${each.value.name}.tf"
}

# Generate entry point file that imports all of the generated modules in the root directory.
resource "local_file" "generate_main" {
  content = join("\n", concat([for alias, _ in local.zones : <<EOT

          module "aws_${alias}" {
            source = "./generated/${alias}"
          }

          # output "aws_${alias}_proxy_public_ip" {
          #   value = module.aws_${alias}.aws_proxy_${alias}_public_ip
          # }
EOT
    ], [
    for key, instance in local.unique_instances : <<EOT

          output "aws_${key}_public_ip" {
            value = module.aws_${instance.zone_alias}.aws_instance_${instance.name}_public_ip
          }
EOT
    ], [
    for region_alias, _ in local.regions : <<EOT

          module "aws_${region_alias}" {
            source = "./generated/${region_alias}"
          }
      EOT
    ]
  ))

  filename = "${path.root}/generated_main.tf"
}
