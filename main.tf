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

resource "azurerm_virtual_network" "web_server_vnet" {
  name                = "${var.resource_prefix}-vnet"
  location            = var.web_server_location
  resource_group_name = azurerm_resource_group.webserver_rg.name
  address_space       = [var.web_server_address_space]
}

resource "azurerm_subnet" "web_server_subnet" {
  name                 = "${var.resource_prefix}-subnet"
  resource_group_name  = azurerm_resource_group.webserver_rg.name
  virtual_network_name = azurerm_virtual_network.web_server_vnet.name
  address_prefix       = var.web_server_address_prefix
}

resource "azurerm_network_interface" "web_server_nic" {
  name                = "${var.web_server_name}-nic"
  location            = var.web_server_location
  resource_group_name = azurerm_resource_group.webserver_rg.name
  ip_configuration {
    name                          = "${var.web_server_name}-ip"
    subnet_id                     = azurerm_subnet.web_server_subnet.id
    private_ip_address_allocation = "dynamic"
    // Adding public ip to NIC
    public_ip_address_id = azurerm_public_ip.webserver_public_ip.id
  }
}

resource "azurerm_public_ip" "webserver_public_ip" {
  name                = "${var.resource_prefix}-public-ip"
  location            = var.web_server_location
  resource_group_name = azurerm_resource_group.webserver_rg.name
  allocation_method   = var.environment == "production" ? "Static" : "Dynamic"
}

resource "azurerm_network_security_group" "webserver_nsg" {
  name                = "${var.resource_prefix}-nsg"
  location            = var.web_server_location
  // By using this instead of (var.web_server_rg) we are creating, 
  // a soft dependency and waiting for resource group to be created before creating NSG
  resource_group_name = azurerm_resource_group.webserver_rg.name
}

resource "azurerm_network_security_rule" "webserver_nsg_rule_rdp" {
  name                        = "RDP Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.webserver_rg.name
  network_security_group_name = azurerm_network_security_group.webserver_nsg.name
}

resource "azurerm_network_interface_security_group_association" "webserver_nsg_association" {
  network_security_group_id = azurerm_network_security_group.webserver_nsg.id
  network_interface_id = azurerm_network_interface.web_server_nic.id
}

resource "azurerm_windows_virtual_machine" "webserver_vm" {
  name = var.web_server_name
  location = var.web_server_location
  resource_group_name = azurerm_resource_group.webserver_rg.name
  size = "Standard_B1s"
  // VM is associated with NIC (network interface card) and 
  // NIC is associated with public IP.
  network_interface_ids = [azurerm_network_interface.web_server_nic.id]

  admin_username = "webserver"
  admin_password = "Passw0rd12345"
  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer = "WindowsServer"
    sku = "2019-Datacenter"
    version = "latest"
  }
}

// commands used
// az login - login to azure so as to connect where to create the resource
// terraform init - initialise terraform
// terraform fmt - to formate the code
// terraform plan - generates the state, what actually will get deployed
// terraform apply - to deploy the generated state to azure
// terraform destroy - to destroy the generated state
// terraform graph - to create a dependency graph ( Web site : https://dreampuf.github.io/GraphvizOnline/)
// az vm list -o table
// az vm list-sizes -l westus2 -o table
