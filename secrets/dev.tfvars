resource_group_name = "NTGLab-Test"

location = "Southeast Asia"

#-----------------
# Virtual Network
#-----------------
vnet_name = "Test-VNet"

vnet_address_space = ["10.0.0.0/16"]

subnets = {
  private_subnet = {
    subnet_name             = "private-subnet"
    subnet_address_prefix   = ["10.0.1.0/24"]
    subnet_service_endpoint = ["Microsoft.Storage"]
    nsg_inbound_rules = [
      # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
      ["sqlengine", "100", "Inbound", "Allow", "Tcp", "1433", "*", "*"],
      ["rdp", "101", "Inbound", "Allow", "Tcp", "3389", "*", "*"],
    ]
  }
}
#-----------------
# Virtual Machine
#-----------------
vms = {
  ad_vm = {
    vm_name   = "ad-vm"
    pip_name  = "ad-pip"
    vnic_name = "ad-nic"
    ip_config = {
      name       = "ipconfig"
      private_ip = "10.0.1.4"
    }
    vm_size = "Standard_A1_v2"
  }
  sql01_vm = {
    vm_name   = "sql01-vm"
    pip_name  = "sql01-pip"
    vnic_name = "sql01-nic"
    ip_config = {
      name       = "ipconfig"
      private_ip = "10.0.1.5"
    }
    vm_size = "Standard_A2_v2"
  }
  sql02_vm = {
    vm_name   = "sql02-vm"
    pip_name  = "sql02-pip"
    vnic_name = "sql02-nic"
    ip_config = {
      name       = "ipconfig"
      private_ip = "10.0.1.6"
    }
    vm_size = "Standard_A2_v2"
  }
}
#--------------------
# Automation Account
#--------------------
aa_name = "Test-AA"

aa_modules = {
  SqlServerDsc                 = "https://www.powershellgallery.com/api/v2/package/SqlServerDsc/15.1.1"
    xPSDesiredStateConfiguration = "https://www.powershellgallery.com/api/v2/package/xPSDesiredStateConfiguration/9.1.0"
    ActiveDirectoryDsc           = "https://www.powershellgallery.com/api/v2/package/ActiveDirectoryDsc/6.0.1"
    xDnsServer                   = "https://www.powershellgallery.com/api/v2/package/xDnsServer/2.0.0"
    NetworkingDsc                = "https://www.powershellgallery.com/api/v2/package/NetworkingDsc/8.2.0"
    xFailOverCluster             = "https://www.powershellgallery.com/api/v2/package/xFailOverCluster/1.15.0"
}

aa_dscfiles = {
  "ADServer"     = "DSC/AD.ps1"
  "SqlPrimary"   = "DSC/SqlPrimary.ps1"
  "SqlSecondary" = "DSC/SqlSecondary.ps1"
}
#---------------
# Load Balancer
#---------------
lb_name = "Test-LB"

lb_internal = {
  private_lb = {
    frontend1 = {
      fe_privateip    = "10.0.1.10"
      probe_name      = "AlwaysOnProbe"
      probe_port      = "59999"
      rule_name       = "AlwaysOnRule"
      rule_feport     = "1433"
      rule_beport     = "1433"
      feipconfig_name = "frontend1"

    }
    frontend2 = {
      fe_privateip    = "10.0.1.11"
      probe_name      = "WSFCProbe"
      probe_port      = "58888"
      rule_name       = "WSFCRule"
      rule_feport     = "58888"
      rule_beport     = "58888"
      feipconfig_name = "frontend2"
    }
  }
}