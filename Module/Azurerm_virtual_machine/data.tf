data "azurerm_subnet" "subnet" {
  for_each = var.vms

  name                 = each.value.subnet_name
  resource_group_name  = each.value.resource_group_name
  virtual_network_name = each.value.virtual_network_name
}

data "azurerm_public_ip" "public_ip" {
  for_each = var.vms

  name                = each.value.public_ip_name
  resource_group_name = each.value.resource_group_name
}

 data "azurerm_network_security_group" "nsg" {
  for_each = var.vms

  name                = each.value.nsg_name
  resource_group_name = each.value.resource_group_name
}


data "azurerm_key_vault" "keyvault" {
  name                = "rahul-vault12"
  resource_group_name = "Axoin_system12"
}



data "azurerm_key_vault_secret" "password" {
  name         = "password"
  key_vault_id = data.azurerm_key_vault.keyvault.id
}


