provider "azurerm" {
  features {}
}

module "resource-group" {
  source = "../../az-modules/resource-group/"

  resource_group_name = var.resource_group_name
  location            = var.location
}

#-----------------
# Virtual Network
#-----------------
module "virtual-network" {
  source = "../../az-modules/virtual-network/"

  resource_group_name = module.resource-group.az_rg_name
  location            = module.resource-group.az_rg_location

  name          = var.vnet_name
  vnic_name     = var.vnet_vnic_name
  ipconfig_name = var.vnet_ipconfig_name
  address_space = var.vnet_address_space
  subnets       = var.vnet_subnets
}

#----------------
# Security Group
#----------------
module "security-group" {
  source = "../../az-modules/security-group/"

  resource_group_name = module.resource-group.az_rg_name
  location            = module.resource-group.az_rg_location

  name = var.nsg_name

  nsg_rules = var.nsg_rules
}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = element(tolist(module.virtual-network.az_vnic_ids), 0)
  network_security_group_id = module.security-group.az_nsg_id
}

#-----------------
# Virtual Machine
#-----------------
resource "azurerm_windows_virtual_machine" "main" {
  resource_group_name = module.resource-group.az_rg_name
  location            = module.resource-group.az_rg_location

  name = var.vm_name

  network_interface_ids = module.virtual-network.az_vnic_ids
  size                  = var.vm_size
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
# Automation Account
#--------------------
module "automation-account" {
  source = "../../az-modules/automation-account/"

  resource_group_name = module.resource-group.az_rg_name
  location            = module.resource-group.az_rg_location

  name = var.aa_name

  modules     = var.aa_modules
  vm_id       = azurerm_windows_virtual_machine.main.id
  credentials = var.aa_credentials

  depends_on = [
    azurerm_windows_virtual_machine.main
  ]
}

resource "azurerm_automation_dsc_configuration" "az_aa_dscc_sql" {
  resource_group_name = module.resource-group.az_rg_name
  location            = module.resource-group.az_rg_location

  for_each = var.aa_dscfiles
  name     = each.key

  automation_account_name = module.automation-account.az_aa_name


  content_embedded = file("${path.cwd}/${each.value}")
}