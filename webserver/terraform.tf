// we can name this file anything,
// preferred is terraform.tf or backend.tf

terraform {
  backend "azurerm" {
    resource_group_name  = "remote-state"
    storage_account_name = "remotestatestg"
    container_name       = "tfstate"
    key                  = "web.tfstate"
  }
}