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

resource "azurerm_resource_group" "webserver_rg" {
  name     = var.web_server_rg
  location = var.web_server_location
}

// commands used
// az login - login to azure so as to connect where to create the resource
// terraform init - initialise terraform
// terraform fmt - to formate the code
// terraform plan - generates the state, what actually will get deployed
// terraform apply - to deploy the generated state to azure
// terraform destroy - to destroy the generated state
