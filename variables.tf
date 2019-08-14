variable "instance_count" {
  description = "The number of instances to create."
  default     = 1
}

variable "connection" {
  description = "The provisioner connection configuration."
  default     = {}
}

variable "storage_image_reference" {
  description = "A storage_image_reference block."
  type        = map(string)
}

variable "default_user" {
  description = "The cloud-init default user."
  default     = "terraform"
}

variable "vm_size" {
  description = "Specifies the size of the Virtual Machine."
}

variable "domain" {
  description = "The domain name of the instance."
}

variable "module_name" {
  description = "The name of the module used to generate some resources' name."
}

variable "resource_group_name" {
  description = "Specifies the name of the Resource Group in which the Virtual Machine should exist."
}

variable "network_security_group_id" {
  description = "The ID of the Network Security Group to associate with the network interface."
}

variable "subnet_id" {
  description = "Reference to a subnet in which this NIC has been created."
}

variable "key_data" {
  description = "The Public SSH Key which should be written to the default account."
}

variable "os_disk_size_gb" {
  description = "Specifies the size of the OS Disk in gigabytes."
  default     = ""
}

variable "os_managed_disk_type" {
  description = "Specifies the type of Managed Disk which should be created."
  default     = ""
}

variable "tags" {
  description = "A mapping of tags to assign to the resources of this module."
  default     = {}
}

#########
# Puppet

variable "puppet" {
  description = "Puppet related variables."
  type        = map(string)
  default     = null
}
