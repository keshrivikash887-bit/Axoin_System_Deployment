resource "azurerm_network_interface" "nic_name" {
    for_each = var.vms
  name                = each.value.nic_name
  location            = each.value.location
  resource_group_name = each.value.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.subnet[each.key].id
    public_ip_address_id =           data.azurerm_public_ip.public_ip[each.key].id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  for_each = var.vms

  network_interface_id = azurerm_network_interface.nic_name[each.key].id
  network_security_group_id = data.azurerm_network_security_group.nsg[each.key].id
}

resource "azurerm_linux_virtual_machine" "virtual_machine" {
  for_each = var.vms

  name                = each.value.vm_name
  resource_group_name = each.value.resource_group_name
  location            = each.value.location
  size                = each.value.vm_size

   admin_username = "Kuldeep@admin"
 admin_password = data.azurerm_key_vault_secret.password.value

  disable_password_authentication = false

  network_interface_ids = [
  azurerm_network_interface.nic_name[each.key].id
]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
