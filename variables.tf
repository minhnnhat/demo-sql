variable "resource_group_name" {
  description = "Resource group name"
  default     = ""
}

variable "location" {
  description = "Location name"
  default     = ""
}

#-----------------
# Virtual Network
#-----------------
variable "vnet_name" {
  description = "Name of virtual network"
  default     = ""
}

variable "vnet_address_space" {
  description = "Address space used in virtual network"
  default     = []
}

variable "vnet_vnic_name" {
  description = "Name of virtual network interface"
  default     = ""
}

variable "vnet_ipconfig_name" {
  description = "Name of ip configuration"
  default     = ""
}

variable "vnet_subnets" {
  description = "For each subnet, create an object that contain fields"
  type        = map(any)
  default     = {}
}

#----------------
# Security Group
#----------------
variable "nsg_name" {
  description = "Name of network security group"
  default     = ""
}

variable "nsg_rules" {
  description = "Define network security group rules"
  type        = map(any)
  default     = {}
}

#-----------------
# Virtual Machine
#-----------------
variable "vm_name" {
  description = "Name of windows virtual machine"
  default     = ""
}

variable "vm_size" {
  description = "Size of windows virtual machine"
  default     = ""
}

variable "vm_user" {
  description = "Windows virtual machine's user"
  default     = ""
}

variable "vm_pass" {
  description = "Windows virtual machine's password"
  default     = ""
}

#--------------------
# Automation Account
#--------------------
variable "aa_name" {
  description = "Name of automation account"
  default     = ""
}

variable "aa_modules" {
  description = "Modules used in DSC"
  type        = map(any)
  default     = {}
}

variable "aa_credentials" {
  description = "Credentials used in DSC"
  type        = map(any)
  default     = {}
}

variable "aa_dscfiles" {
  description = "DSC files"
  type        = map(any)
  default     = {}
}
