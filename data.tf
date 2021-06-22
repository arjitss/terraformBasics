data "azurerm_key_vault" "azure-key-vault" {
  name                = "learnterraform-keyvault"
  resource_group_name = "remote-state"
}

data "azurerm_key_vault_secret" "az_vm_password" {
  name         = "az-vm-password"
  key_vault_id = data.azurerm_key_vault.azure-key-vault.id
}