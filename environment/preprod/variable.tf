variable "rg_names" {}
variable "vnet_name" {}
variable "subnet_name" {
  type = map(object({
    name                 = string
    virtual_network_name = string
    resource_group_name  = string
    address_prefixes     = list(string)
  }))
}
variable "public_ip" {}
variable "nsg_name" {
  type = map(object({
    name                = string
    location            = string
    resource_group_name = string

    security_rules = list(object({
      name                       = string
      priority                   = number
      direction                  = string
      access                     = string
      protocol                   = string
      source_port_range          = string
      destination_port_range     = string
      source_address_prefix     = string
      destination_address_prefix = string
    }))
  }))
}
variable "vms" {}

variable "bastions" {
  type = map(object({
    name                = string
    location            = string
    rg_name             = string
    subnet_name         = string
    vnet_name           = string
    public_ip_name      = string
  }))
}

