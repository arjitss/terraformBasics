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

locals {
  build_enviornment = var.environment == "production" ? "production" : "development"
}

resource "azurerm_resource_group" "webserver_rg" {
  name     = var.web_server_rg
  location = var.web_server_location
  tags = {
    environment   = local.build_enviornment
    build_version = var.terraform_my_resource_script_version
  }
}

resource "azurerm_virtual_network" "web_server_vnet" {
  name                = "${var.resource_prefix}-vnet"
  location            = var.web_server_location
  resource_group_name = azurerm_resource_group.webserver_rg.name
  address_space       = [var.web_server_address_space]
}


resource "azurerm_storage_account" "storage_account" {

  name                     = "ltfbootdiagnostics01"
  location                 = var.web_server_location
  resource_group_name      = azurerm_resource_group.webserver_rg.name
  access_tier              = "Standard"
  account_replication_type = "LRS"
}

# resource "azurerm_subnet" "web_server_subnet" {
#   name                 = "${var.resource_prefix}-subnet"
#   resource_group_name  = azurerm_resource_group.webserver_rg.name
#   virtual_network_name = azurerm_virtual_network.web_server_vnet.name
#   address_prefix       = var.web_server_address_prefix
# }


resource "azurerm_subnet" "web_server_subnet" {
  for_each             = var.web_server_subnets
  name                 = each.key
  resource_group_name  = azurerm_resource_group.webserver_rg.name
  virtual_network_name = azurerm_virtual_network.web_server_vnet.name
  address_prefix       = each.value
}

# This does move to Azure Scale Set, once scale set is created
#--------------------------------------------------------------
# resource "azurerm_network_interface" "web_server_nic" {
#   name                = "${var.web_server_name}-${format("%02d", count.index)}-nic"
#   location            = var.web_server_location
#   resource_group_name = azurerm_resource_group.webserver_rg.name
#   count               = var.web_server_count
#   ip_configuration {
#     name                          = "${var.web_server_name}-ip"
#     subnet_id                     = azurerm_subnet.web_server_subnet["web-server"].id
#     private_ip_address_allocation = "dynamic"
#     // Adding public ip to NIC
#     public_ip_address_id = count.index == 0 ? azurerm_public_ip.webserver_public_ip.id : null
#   }
# }

resource "azurerm_public_ip" "webserver_public_ip" {
  name                = "${var.resource_prefix}-public-ip"
  location            = var.web_server_location
  resource_group_name = azurerm_resource_group.webserver_rg.name
  allocation_method   = var.environment == "production" ? "Static" : "Dynamic"
}

resource "azurerm_network_security_group" "webserver_nsg" {
  name     = "${var.resource_prefix}-nsg"
  location = var.web_server_location
  // By using this instead of (var.web_server_rg) we are creating, 
  // a soft dependency and waiting for resource group to be created before creating NSG
  resource_group_name = azurerm_resource_group.webserver_rg.name
}


// NSG rule for RDP
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
  count                       = var.environment == "development" ? 1 : 0 // A binary varibale to create the resource based on condition
}

// NSG rule for HTTP (required for Load balancer)
resource "azurerm_network_security_rule" "webserver_nsg_rule_http" {
  name                        = "HTTP Inbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.webserver_rg.name
  network_security_group_name = azurerm_network_security_group.webserver_nsg.name
}

resource "azurerm_subnet_network_security_group_association" "webserver_sag" {
  network_security_group_id = azurerm_network_security_group.webserver_nsg.id
  subnet_id                 = azurerm_subnet.web_server_subnet["web-server"].id
}

# Using scale set configs.
# ------------------------
# resource "azurerm_windows_virtual_machine" "webserver_vm" {
#   name                = "${var.web_server_name}-${format("%02d", count.index)}"
#   location            = var.web_server_location
#   resource_group_name = azurerm_resource_group.webserver_rg.name
#   size                = "Standard_B1s"
#   count               = var.web_server_count
#   // VM is associated with NIC (network interface card) and 
#   // NIC is associated with public IP.
#   network_interface_ids = [azurerm_network_interface.web_server_nic[count.index].id]

#   // adding the VM to the availability set
#   availability_set_id = azurerm_availability_set.webserver_availability_set.id

#   admin_username = "webserver"
#   admin_password = "Passw0rd12345"
#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }
#   source_image_reference {
#     publisher = "MicrosoftWindowsServer"
#     offer     = "WindowsServer"
#     sku       = "2019-Datacenter"
#     version   = "latest"
#   }
# }

resource "azurerm_virtual_machine_scale_set" "web_server" {
  name                = "${var.resource_prefix}-scale-set"
  location            = var.web_server_location
  resource_group_name = azurerm_resource_group.webserver_rg.name
  upgrade_policy_mode = "manual"
  sku {
    name     = "Standard_B1s"
    tier     = "Standard"
    capacity = var.web_server_count
  }
  storage_profile_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name_prefix = var.web_server_name
    admin_username       = "webserver"
    admin_password       = data.azurerm_key_vault_secret.az_vm_password.value
  }
  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = true
  }
  network_profile {
    name    = "web_server_network_profile"
    primary = true
    ip_configuration {
      name      = var.web_server_name
      primary   = true
      subnet_id = azurerm_subnet.web_server_subnet["web-server"].id
      // add a new backend ip pool property to point these VM in load balancer backend pool
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web_server_lb_backend_pool.id]
    }
  }

  // Azure VM extentions

  extension {
    name                 = "${var.resource_prefix}-extentions"
    publisher            = "Microsoft.Compute"
    type                 = "CustomScriptExtension"
    type_handler_version = "1.10"

    settings = <<SETTINGS
{
  "fileUris" : ["https://raw.githubusercontent.com/eltimmo/learning/master/azureInstallWebServer.ps1"],
  "commandToExecute" : "start powershell -ExecutionPolicy Unrestricted -File azureInstallWebServer.ps1"
}
  SETTINGS
  }

}

// load balancer
resource "azurerm_lb" "web_server_lb" {
  name                = "${var.resource_prefix}-lb"
  location            = var.web_server_location
  resource_group_name = azurerm_resource_group.webserver_rg.name
  // public ip (frontend ip for load balancer)
  frontend_ip_configuration {
    name                 = "${var.resource_prefix}-lb-frontend-ip"
    public_ip_address_id = azurerm_public_ip.webserver_public_ip.id
  }
}

// backend address pool
resource "azurerm_lb_backend_address_pool" "web_server_lb_backend_pool" {
  name                = "${var.resource_prefix}-lb-backend-pool"
  resource_group_name = azurerm_resource_group.webserver_rg.name
  loadbalancer_id     = azurerm_lb.web_server_lb.id
}

resource "azurerm_lb_probe" "web_server_lb_http_probe" {
  name                = "${var.resource_prefix}-lb-http-probe"
  resource_group_name = azurerm_resource_group.webserver_rg.name
  loadbalancer_id     = azurerm_lb.web_server_lb.id
  protocol            = "tcp"
  port                = "80"
}

resource "azurerm_lb_rule" "web_server_lb_http_rule" {
  name                           = "${var.resource_prefix}-lb-http-probe"
  resource_group_name            = azurerm_resource_group.webserver_rg.name
  loadbalancer_id                = azurerm_lb.web_server_lb.id
  protocol                       = "tcp"
  frontend_port                  = "80"
  backend_port                   = "80"
  frontend_ip_configuration_name = "${var.resource_prefix}-lb-frontend-ip"
  probe_id                       = azurerm_lb_probe.web_server_lb_http_probe.id
  backend_address_pool_id        = azurerm_lb_backend_address_pool.web_server_lb_backend_pool.id
}


# Not required as we are trying out Scale set
# ------------------------------------------- 
# resource "azurerm_availability_set" "webserver_availability_set" {
#   name                        = "${var.web_server_name}-availability_set"
#   location                    = var.web_server_location
#   resource_group_name         = azurerm_resource_group.webserver_rg.name
#   managed                     = true
#   platform_fault_domain_count = 2
# }

// commands used
// az login - login to azure so as to connect where to create the resource
// terraform init - initialise terraform
// terraform fmt - to formate the code
// terraform plan - generates the state, what actually will get deployed
// terraform apply - to deploy the generated state to azure
// terraform destroy - to destroy the generated state
// terraform graph - to create a dependency graph ( Web site : https://dreampuf.github.io/GraphvizOnline/)
// terraform import - to import a resource in Terraform state to manage it via Terraform, 
//                    which previous was not created by Terraform
// az vm list -o table
// az vm list-sizes -l westus2 -o table

//----
// For adding an existing resource or a resource which is not created by our Terraform script to our State file
// We need to go the resource (lets say its a storage account) and the we need to 
// get the resource id (`Storage account resource ID` in this case) and then exute 
// command `terraform import` providing resource type and its name and then its resource id.
// example : terraform import azurerm_storage_account.storage_account /subscriptions/3f1c0905-3283-4f97-8bdb-edc61ac96358/resourceGroups/web-rg/providers/Microsoft.Storage/storageAccounts/ltfbootdiagnostics01
// example explain: terraform import  - P1: type of resource 
//                                    - P2: Name provided in terraform file 
//                                    - P3: Resource Id
//----

// Error Logging to read more on google:
// --------------------------------------
// TF_LOG = TRACE, DEBUG, INFO, WARN or ERROR
// TF_LOG_PATH
// crash.log
