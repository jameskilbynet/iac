# Variables for vSphere and VM configuration

variable "vsphere_user" {
  description = "vSphere username"
  type        = string
  sensitive   = true
}

variable "vsphere_password" {
  description = "vSphere password"
  type        = string
  sensitive   = true
}

variable "vsphere_server" {
  description = "vSphere server address"
  type        = string
  default     = "vcenter.example.com"
}

variable "data_center" {
  description = "vSphere data center name"
  type        = string
  default     = "Datacenter"
}

variable "datastore" {
  description = "vSphere datastore name"
  type        = string
  default     = "datastore1"
}

variable "resource_pool" {
  description = "vSphere resource pool name"
  type        = string
  default     = "Resources"
}

variable "network_name" {
  description = "vSphere network name"
  type        = string
  default     = "VM Network"
}

variable "content_library_name" {
  description = "Name of the vSphere Content Library"
  type        = string
  default     = "ContentLib"
}

variable "content_library_item_name" {
  description = "Name of the Photon OVA item in the Content Library"
  type        = string
  default     = "PhotonOS"
}

variable "vm_name" {
  description = "Name of the VM"
  type        = string
  default     = "photon-vm"
}

variable "vm_folder" {
  description = "vSphere folder path for the VM"
  type        = string
  default     = "Workloads"
}

variable "vm_hostname" {
  description = "Hostname for the Photon VM"
  type        = string
  default     = "photon-vm"
}

variable "domain" {
  description = "Domain for the Photon VM"
  type        = string
  default     = "example.com"
}

variable "ipv4_address" {
  description = "Static IPv4 address for the VM"
  type        = string
  default     = "192.168.1.100"
}

variable "ipv4_gateway" {
  description = "IPv4 gateway for the VM"
  type        = string
  default     = "192.168.1.1"
}

variable "dns_server" {
  description = "DNS server for the VM"
  type        = string
  default     = "8.8.8.8"
}