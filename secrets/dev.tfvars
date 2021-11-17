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
      ["dbmirror", "102", "Inbound", "Allow", "Tcp", "5022", "*", "*"],
      ["aglb", "103", "Inbound", "Allow", "Tcp", "58888", "*", "*"],
      ["clusterlb", "104", "Inbound", "Allow", "Tcp", "59999", "*", "*"],
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
    vnic_name = "private-ad-nic"
    ip_config = {
      name       = "private-ipconfig"
      private_ip = "10.0.1.4"
    }
    vm_size = "Standard_B1ms"
  }
  sql01_vm = {
    vm_name   = "sql01-vm"
    pip_name  = "sql01-pip"
    vnic_name = "private-sql01-nic"
    ip_config = {
      name       = "private-ipconfig"
      private_ip = "10.0.1.5"
    }
    vm_size = "Standard_B2s"
  }
  sql02_vm = {
    vm_name   = "sql02-vm"
    pip_name  = "sql02-pip"
    vnic_name = "private-sql02-nic"
    ip_config = {
      name       = "private-ipconfig"
      private_ip = "10.0.1.6"
    }
    vm_size = "Standard_B2s"
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
  DnsServerDsc                 = "https://www.powershellgallery.com/api/v2/package/DnsServerDsc/3.0.0"
  NetworkingDsc                = "https://www.powershellgallery.com/api/v2/package/NetworkingDsc/8.2.0"
  xFailOverCluster             = "https://www.powershellgallery.com/api/v2/package/xFailOverCluster/1.16.0"
}

aa_dscfiles = {
  "ADServer"              = "DSC/AD.ps1"
  "SqlPrimary"            = "DSC/SqlPrimary.ps1"
  "SqlSecondary"          = "DSC/SqlSecondary.ps1"
}
#---------------
# Load Balancer
#---------------
lb_name = "Test-LB"

lb_internal = {
  private_lb = {
    frontend1 = {
      fe_privateip    = "10.0.1.9"
      probe_name      = "AlwaysOnProbe"
      probe_port      = "59999"
      rule_name       = "AlwaysOnRule"
      rule_feport     = "1433"
      rule_beport     = "1433"
      feipconfig_name = "AlwaysOnFrontIP"

    }
    frontend2 = {
      fe_privateip    = "10.0.1.8"
      probe_name      = "WSFCProbe"
      probe_port      = "58888"
      rule_name       = "WSFCRule"
      rule_feport     = "58888"
      rule_beport     = "58888"
      feipconfig_name = "WSFCFrontIP"
    }
  }
}