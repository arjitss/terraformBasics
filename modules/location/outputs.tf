output "web_server_lb_public_ip_id" {
  value = azurerm_public_ip.webserver_public_ip.id
}

output "bastion_host_subnets" {
  value = azurerm_subnet.web_server_subnet["AzureBastionSubnet"].id
}