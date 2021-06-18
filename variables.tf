# data "http" "myip" {
#     url = "https://api.ipify.org/"
# }

variable "resource_group_name" {
  description = "Resource group name"
}

variable "location" {
  description = "Resource group location"
}

variable "vnet_name" {
  description = "Virtual network name"
}

variable "vnet_address_space" {
  description = "Address space"
}

variable "subnets" {
  description = "Subnet information"
  default = {}
}

variable "vms" {
  default = {
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
}

variable "vm_user" {
  description = "Virtual machine username"
}

variable "vm_pass" {
  description = "Virtual machine password"
}

variable "aa_name" {
  description = "Name of automation account"
}

variable "aa_modules" {
  description = "Modules used in DSC"
  type        = map(any)
  default = {}
}

variable "aa_credentials" {
  description = "Credentials used in DSC"
  type        = map(any)
  default = {}
}

variable "aa_dscfiles" {
  description = "DSC files"
  type        = map(any)
  default = {}
}

variable "lb_internal" {
  description = "Load Balancer"
  default = {}
}

variable "lb_name" {
  description = "Load balance name"
}