# vSphere Connection Variables
variable "vsphere_user" {
  description = "vSphere username"
  type        = string
}

variable "vsphere_password" {
  description = "vSphere password"
  type        = string
  sensitive   = true
}

variable "vsphere_server" {
  description = "vSphere server hostname or IP"
  type        = string
}

# vSphere Infrastructure Variables
variable "datacenter" {
  description = "vSphere datacenter name"
  type        = string
}

variable "datastore" {
  description = "vSphere datastore name"
  type        = string
}

variable "cluster" {
  description = "vSphere cluster name"
  type        = string
}

variable "network" {
  description = "vSphere network name"
  type        = string
}

variable "vm_folder" {
  description = "vSphere folder path for VM placement"
  type        = string
}

# Template and VM Variables
variable "template_name" {
  description = "Name of the Ubuntu template to clone from"
  type        = string
}

variable "vm_name" {
  description = "Name for the new Ubuntu VM"
  type        = string
}

variable "num_cpus" {
  description = "Number of CPUs for the VM"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory in MB for the VM"
  type        = number
  default     = 4096
}

variable "disk_size" {
  description = "Disk size in GB (optional, will use template size if not specified)"
  type        = number
  default     = null
}

# VM Customization Variables
variable "customize_vm" {
  description = "Whether to customize the VM with specific network settings"
  type        = bool
  default     = false
}

variable "hostname" {
  description = "Hostname for the VM (required if customize_vm is true)"
  type        = string
  default     = ""
}

variable "domain" {
  description = "Domain name for the VM (required if customize_vm is true)"
  type        = string
  default     = ""
}

variable "ipv4_address" {
  description = "Static IPv4 address for the VM (required if customize_vm is true)"
  type        = string
  default     = ""
}

variable "ipv4_netmask" {
  description = "IPv4 netmask (required if customize_vm is true)"
  type        = number
  default     = 24
}

variable "ipv4_gateway" {
  description = "IPv4 gateway (required if customize_vm is true)"
  type        = string
  default     = ""
}

variable "dns_servers" {
  description = "List of DNS servers (required if customize_vm is true)"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

# Timeout Variables
variable "wait_for_guest_ip_timeout" {
  description = "Timeout in minutes to wait for guest IP"
  type        = number
  default     = 5
}

variable "wait_for_guest_net_timeout" {
  description = "Timeout in minutes to wait for guest network"
  type        = number
  default     = 5
} 