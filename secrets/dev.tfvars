resource_group_name = "NTGLab-Dev"

location = "eastasia"

#-----------------
# Virtual Network
#-----------------
vnet_name = "vnet-dev"

vnet_address_space = ["10.0.0.0/16"]

vnet_vnic_name = "nic-dev"

vnet_ipconfig_name = "ipconfig-dev"

vnet_subnets = {
    subnet0 = {
      subnet_name           = "subnet0"
      subnet_address_prefix = ["10.0.1.0/24"]
      service_endpoints     = ["Microsoft.Storage"]
    }
}

#----------------
# Security Group
#----------------
nsg_name = "nsg-dev"

nsg_rules = {
    rdp = {
      name                       = "rdp"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3389"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
    sql = {
      name                       = "sql"
      priority                   = 101
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "1433"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
}

#-----------------
# Virtual Machine
#-----------------
vm_name = "vm-dev"

vm_size = "Standard_A2_v2"

#--------------------
# Automation Account
#--------------------
aa_name = "aa-dev"

aa_modules = {
    SqlServerDsc = "https://www.powershellgallery.com/api/v2/package/SqlServerDsc/15.1.1"
    xPSDesiredStateConfiguration = "https://www.powershellgallery.com/api/v2/package/xPSDesiredStateConfiguration/9.1.0"
}

aa_dscfiles = {
  "xSQLInstance" = "DSC/SQLInstance.ps1"
}