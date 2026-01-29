variable "datacenter_id" {
  description = "vSphere datacenter ID"
  type        = string
}

variable "datastore_id" {
  description = "Datastore ID for VM"
  type        = string
}

variable "resource_pool_id" {
  description = "Resource pool ID"
  type        = string
}

variable "network_id" {
  description = "Network ID for management interface"
  type        = string
}

variable "folder_path" {
  description = "VM folder path"
  type        = string
}

variable "hostname" {
  description = "Hostname for ESXi"
  type        = string
}

variable "domain" {
  description = "Domain name"
  type        = string
}

variable "num_cpus" {
  description = "Number of CPUs"
  type        = number
}

variable "num_cores_per_socket" {
  description = "Cores per socket"
  type        = number
}

variable "memory_mb" {
  description = "Memory in MB"
  type        = number
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
}

variable "cache_disk_size_gb" {
  description = "vSAN cache disk size in GB"
  type        = number
}

variable "capacity_disk_size_gb" {
  description = "vSAN capacity disk size in GB"
  type        = number
}

variable "root_password" {
  description = "Root password for ESXi"
  type        = string
  sensitive   = true
}

variable "management_ip" {
  description = "Management IP address"
  type        = string
}

variable "management_netmask" {
  description = "Management network netmask (CIDR format)"
  type        = string
}

variable "gateway" {
  description = "Default gateway"
  type        = string
}

variable "dns_servers" {
  description = "List of DNS servers"
  type        = list(string)
}
