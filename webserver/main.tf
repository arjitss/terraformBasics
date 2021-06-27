terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "random" {
  version = "2.2"
}

module "location_us2w" {
  source                   = "./modules/location"
  web_server_location      = "westus2"
  web_server_rg            = "${var.web_server_rg}-us2w"
  resource_prefix          = "${var.resource_prefix}-us2w"
  web_server_address_space = "1.0.0.0/22"
  web_server_name          = var.web_server_name
  environment              = var.environment
  web_server_count         = var.web_server_count
  web_server_subnets = {
    web-server         = "1.0.1.0/24"
    AzureBastionSubnet = "1.0.2.0/24"
  }
  terraform_my_resource_script_version = var.terraform_my_resource_script_version
  // this is quite important, how to pass value from keyvault to module
  admin_password    = data.azurerm_key_vault_secret.az_vm_password.value
  domain_name_label = var.domain_name_label
}

module "location_us2e" {
  source                   = "./modules/location"
  web_server_location      = "eastus2"
  web_server_rg            = "${var.web_server_rg}-us2e"
  resource_prefix          = "${var.resource_prefix}-us2e"
  web_server_address_space = "2.0.0.0/22"
  web_server_name          = var.web_server_name
  environment              = var.environment
  web_server_count         = var.web_server_count
  web_server_subnets = {
    web-server         = "2.0.1.0/24"
    AzureBastionSubnet = "2.0.2.0/24"
  }
  terraform_my_resource_script_version = var.terraform_my_resource_script_version
  // this is quite important, how to pass value from keyvault to module
  admin_password    = data.azurerm_key_vault_secret.az_vm_password.value
  domain_name_label = var.domain_name_label
}

resource "azurerm_resource_group" "global_rg" {
  name     = "traffic-manager-rg"
  location = "westus2"
}

resource "azurerm_traffic_manager_profile" "traffic_manager" {
  name                   = "${var.resource_prefix}-traffic-manager"
  resource_group_name    = azurerm_resource_group.global_rg.name
  traffic_routing_method = "Weighted"
  dns_config {
    relative_name = var.domain_name_label
    ttl           = 100
  }
  monitor_config {
    protocol = "http"
    port     = 80
    path     = "/"
  }
}

resource "azurerm_traffic_manager_endpoint" "traffic_manager_us2w" {
  name                = "${var.resource_prefix}-us2w-endpoint"
  resource_group_name = azurerm_resource_group.global_rg.name
  profile_name        = azurerm_traffic_manager_profile.traffic_manager.name
  target_resource_id  = module.location_us2w.web_server_lb_public_ip_id
  type                = "azureEndpoints"
  weight              = 100
}

resource "azurerm_traffic_manager_endpoint" "traffic_manager_us2e" {
  name                = "${var.resource_prefix}-us2e-endpoint"
  resource_group_name = azurerm_resource_group.global_rg.name
  profile_name        = azurerm_traffic_manager_profile.traffic_manager.name
  target_resource_id  = module.location_us2e.web_server_lb_public_ip_id
  type                = "azureEndpoints"
  weight              = 100
}