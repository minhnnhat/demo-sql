provider "azurerm" {
  features {}
}

locals {
  resource_group_name = module.resource-group.az_rg_name
  location            = module.resource-group.az_rg_location
}
#----------------
# Resource group
#----------------
module "resource-group" {
  source = "./az-modules/resource-group"

  resource_group_name = var.resource_group_name
  location            = var.location
}
#------------------------------------
# Virtual network and security group
#------------------------------------
module "virtual-network" {
  source = "./az-modules/virtual-network"

  resource_group_name = local.resource_group_name
  location            = local.location

  name          = var.vnet_name
  address_space = var.vnet_address_space
  subnets       = var.subnets
}
#-----------
# Public IP
#-----------
resource "azurerm_public_ip" "main" {
  resource_group_name = local.resource_group_name
  location            = local.location

  for_each          = var.vms
  name              = each.value.pip_name
  allocation_method = "Static"
  sku               = "Standard"
}
#---------------------------
# Virtual network interface
#---------------------------
resource "azurerm_network_interface" "main" {
  resource_group_name = local.resource_group_name
  location            = local.location

  for_each = var.vms
  name     = each.value.vnic_name

  dynamic "ip_configuration" {
    for_each = [lookup(each.value, "ip_config", "")]
    content {
      name                          = ip_configuration.value["name"]
      subnet_id                     = module.virtual-network.az_subnet_ids[0]
      private_ip_address_allocation = "static"
      private_ip_address            = ip_configuration.value["private_ip"]
      public_ip_address_id          = azurerm_public_ip.main[each.key].id
    }
  }
}

resource "azurerm_network_interface_security_group_association" "main" {
  for_each                  = var.vms
  network_interface_id      = azurerm_network_interface.main[each.key].id
  network_security_group_id = module.virtual-network.az_nsg_ids[0]
}
#----------------
# Avaibility set
#----------------
resource "azurerm_availability_set" "main" {
  resource_group_name = local.resource_group_name
  location            = local.location

  name                         = "test-as"
  platform_update_domain_count = "2"
  platform_fault_domain_count  = "2"
}
#-----------------
# Virtual machine
#-----------------
resource "azurerm_windows_virtual_machine" "main" {
  resource_group_name = local.resource_group_name
  location            = local.location

  for_each = var.vms
  name     = each.value.vm_name

  network_interface_ids = [azurerm_network_interface.main[each.key].id]
  availability_set_id   = azurerm_availability_set.main.id
  timezone              = "SE Asia Standard Time"
  size                  = each.value.vm_size
  admin_username        = var.vm_user
  admin_password        = var.vm_pass

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}
#--------------------
# Automation account
#--------------------
module "automation-account" {
  source = "./az-modules/automation-account"

  resource_group_name = local.resource_group_name
  location            = local.location

  name = var.aa_name

  modules     = var.aa_modules
  vm_ids      = { for k, v in azurerm_windows_virtual_machine.main : k => v.id }
  credentials = var.aa_credentials
  dscfiles    = var.aa_dscfiles

  depends_on = [
    azurerm_windows_virtual_machine.main
  ]
}
#--------------
# Load balance
#--------------
module "load-balancer" {
  source = "./az-modules/load-balancer"

  resource_group_name = local.resource_group_name
  location            = local.location

  name                  = var.lb_name
  lb_internal           = var.lb_internal
  subnet_ids            = module.virtual-network.az_subnet_ids[0]
  network_interface_ids = { for k, v in azurerm_network_interface.main : k => v.id if k == "sql01_vm" || k == "sql02_vm" }
}