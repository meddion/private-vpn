resource "local_file" "nginx_proxy_template" {
  content = templatefile("${path.root}/provision/nginx.tftpl", {
    vm_user = "ubuntu",

    nginx_conf_content = templatefile("${path.root}/provision/proxy.conf.tftpl", {
      nginx_listen_port    = "80"
      nginx_server_name    = "server-name"
      nginx_forward_scheme = "http"
      nginx_proxy_targets  = jsonencode([{ "host" : "10.0.1.45", "port" : "51821", "prefix" : "wg1" }, { "host" : "10.0.1.46", "port" : "51821", "prefix" : "wg2" }])
    }),
  })

  filename = "${path.root}/generated/tests/proxy.sh"
}

resource "local_file" "wg_easy_template" {
  for_each = local.unique_instances

  content = templatefile(local.wg_user_data_tmpl_path, {
    vm_user               = each.value.vm_user
    wg_easy_password_hash = replace(each.value.wg_easy_password_hash, "$$", "\\$\\$")
    wg_vpn_server_address = each.value.wg_vpn_server_address
    wg_vpn_mask           = each.value.wg_vpn_mask
    wg_dns                = each.value.wg_dns
    wg_port               = each.value.wg_port
    wg_easy_web_port      = each.value.wg_easy_web_port
    wg_server_private_key = var.wg_server_private_key
    wg_clients            = jsonencode(var.wg_clients)
    idle_shutdown_script  = file("${path.root}/provision/idle_shutdown.py")
  })

  filename = "${path.root}/generated/tests/wg_easy.sh"
}
