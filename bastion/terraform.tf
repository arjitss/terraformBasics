terraform {
  backend "azurerm" {
    resource_group_name  = "remote-state"
    storage_account_name = "remotestatestg"
    container_name       = "tfstate"
    key                  = "bastion.tfstate"
  }
}