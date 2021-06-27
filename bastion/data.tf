data "terraform_remote_state" "webserver_state" {
  backend = "azurerm"
  config = {
    resource_group_name  = "remote-state"
    storage_account_name = "remotestatestg"
    container_name       = "tfstate"
    key                  = "web.tfstate"
  }
}