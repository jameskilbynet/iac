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
  default     = "uk-bhr-p-vc-1.jameskilby.cloud"
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
  description = "Name of the Windows Server template to clone from"
  type        = string
}

variable "vm_name" {
  description = "Name for the new SQL Server VM"
  type        = string
}

variable "hostname" {
  description = "Computer name/hostname for the VM"
  type        = string
}

# CPU Configuration
variable "num_cpus" {
  description = "Number of virtual CPUs for SQL Server (recommend 4-8+ for production)"
  type        = number
  default     = 8
}

variable "cores_per_socket" {
  description = "Number of cores per CPU socket (affects NUMA)"
  type        = number
  default     = 4
}

variable "cpu_hot_add_enabled" {
  description = "Enable CPU hot add (not recommended for SQL Server)"
  type        = bool
  default     = false
}

variable "cpu_reservation_mhz" {
  description = "CPU reservation in MHz (0 = none)"
  type        = number
  default     = 0
}

variable "cpu_share_level" {
  description = "CPU share level (low, normal, high, custom)"
  type        = string
  default     = "normal"
}

# Memory Configuration
variable "memory" {
  description = "Memory in MB for SQL Server (recommend 16GB+ for production)"
  type        = number
  default     = 32768
}

variable "memory_reservation_enabled" {
  description = "Enable full memory reservation (recommended for production SQL)"
  type        = bool
  default     = true
}

variable "memory_hot_add_enabled" {
  description = "Enable memory hot add (not recommended for SQL Server)"
  type        = bool
  default     = false
}

variable "memory_share_level" {
  description = "Memory share level (low, normal, high, custom)"
  type        = string
  default     = "normal"
}

# Disk Configuration - SQL Server Best Practices
variable "os_disk_size" {
  description = "OS disk size in GB (C: drive)"
  type        = number
  default     = 100
}

variable "sql_data_disk_size" {
  description = "SQL Data disk size in GB (D: drive - for .mdf files)"
  type        = number
  default     = 500
}

variable "sql_log_disk_size" {
  description = "SQL Log disk size in GB (E: drive - for .ldf files)"
  type        = number
  default     = 200
}

variable "tempdb_disk_size" {
  description = "TempDB disk size in GB (T: drive)"
  type        = number
  default     = 100
}

variable "backup_disk_size" {
  description = "Backup disk size in GB (B: drive - 0 to skip)"
  type        = number
  default     = 500
}

variable "thin_provisioned" {
  description = "Use thin provisioning for disks (false for thick provision)"
  type        = bool
  default     = false
}

variable "eagerly_scrub" {
  description = "Enable eager zeroing for thick provisioned disks (recommended for production)"
  type        = bool
  default     = true
}

variable "scsi_controller_type" {
  description = "SCSI controller type (pvscsi recommended for SQL Server)"
  type        = string
  default     = "pvscsi"
}

# Performance Tuning
variable "latency_sensitivity" {
  description = "Latency sensitivity level (normal, low, high)"
  type        = string
  default     = "normal"
}

# Windows Customization Variables
variable "workgroup" {
  description = "Windows workgroup (leave empty if joining domain)"
  type        = string
  default     = "WORKGROUP"
}

variable "admin_password" {
  description = "Local administrator password"
  type        = string
  sensitive   = true
}

variable "timezone" {
  description = "Windows timezone ID (e.g., 085 for GMT)"
  type        = number
  default     = 085
}

variable "run_once_commands" {
  description = "List of commands to run once after deployment"
  type        = list(string)
  default     = []
}

# Network Configuration
variable "ipv4_address" {
  description = "Static IPv4 address for the VM"
  type        = string
}

variable "ipv4_netmask" {
  description = "IPv4 netmask (e.g., 24 for 255.255.255.0)"
  type        = number
  default     = 24
}

variable "ipv4_gateway" {
  description = "IPv4 gateway"
  type        = string
}

variable "dns_servers" {
  description = "List of DNS servers"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

# Timeout Variables
variable "wait_for_guest_ip_timeout" {
  description = "Timeout in minutes to wait for guest IP"
  type        = number
  default     = 10
}

variable "wait_for_guest_net_timeout" {
  description = "Timeout in minutes to wait for guest network"
  type        = number
  default     = 10
}
