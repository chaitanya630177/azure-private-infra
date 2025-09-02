
output "vnet_id" {
  value = azurerm_virtual_network.secure_vnet.id
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "function_app_names" {
  value = [for f in azurerm_linux_function_app.functions : f.name]
}
