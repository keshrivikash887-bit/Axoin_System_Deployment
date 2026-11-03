module "rg" {
  source   = "../../Module/Azurerm_resource_group"
  rg_names = var.rg_names
}
module "vnet" {
    depends_on = [ module.rg ]
  source    = "../../Module/Azurerm_virtual_network"
  vnet_name = var.vnet_name
}
module "subnet" {
    depends_on = [ module.rg,module.vnet ]
  source      = "../../Module/Azurerm_subnet"
  subnet_name = var.subnet_name
}
module "public_ip" {
    depends_on = [ module.rg ]
  source    = "../../Module/Azurerm_public_ip"
  public_ip = var.public_ip
}
module "nsg" {
    depends_on = [ module.rg,module.subnet ]
  source   = "../../Module/Azurerm_nsg"
  nsg_name = var.nsg_name
}
module "vm" {
    depends_on = [ module.subnet,module.nsg ]
  source = "../../Module/Azurerm_virtual_machine"
  vms    = var.vms
}

module "bastion" {
    depends_on = [ module.rg,module.subnet,module.public_ip ]
  source   = "../../Module/azurerm_bastion"
  bastions = var.bastions
}

