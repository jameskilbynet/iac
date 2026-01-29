# vSphere Connection Variables
variable "vsphere_server" {
  description = "vCenter server FQDN or IP"
  type        = string
  default     = "uk-bhr-p-vc-1.jameskilby.cloud"
}

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

# Infrastructure Configuration
variable "datacenter" {
  description = "vSphere datacenter name"
  type        = string
  default     = "uk-bhr-p-dc-1"
}

variable "cluster" {
  description = "vSphere cluster name"
  type        = string
  default     = "uk-bhr-p-cl-1"
}

variable "datastore" {
  description = "Datastore for nested VCF environment"
  type        = string
}

variable "network" {
  description = "Management network for initial connectivity"
  type        = string
}

variable "vm_folder" {
  description = "VM folder for nested VCF VMs"
  type        = string
  default     = "Production/VCF"
}

# Resource Pool Configuration
variable "resource_pool_name" {
  description = "Name of the resource pool for nested VCF"
  type        = string
  default     = "Nested-VCF5"
}

variable "resource_pool_cpu_reservation" {
  description = "CPU reservation in MHz for the resource pool"
  type        = number
  default     = 0
}

variable "resource_pool_memory_reservation" {
  description = "Memory reservation in MB for the resource pool"
  type        = number
  default     = 0
}

# Nested ESXi Configuration
variable "esxi_count" {
  description = "Number of nested ESXi hosts to deploy"
  type        = number
  default     = 4
  validation {
    condition     = var.esxi_count >= 4
    error_message = "VCF requires at least 4 ESXi hosts."
  }
}

variable "esxi_hostname_prefix" {
  description = "Prefix for nested ESXi hostnames"
  type        = string
  default     = "esxi"
}

variable "esxi_domain" {
  description = "Domain name for nested ESXi hosts"
  type        = string
  default     = "vcf.local"
}

variable "esxi_ova_path" {
  description = "Path to nested ESXi OVA (local or content library)"
  type        = string
}

variable "esxi_num_cpus" {
  description = "Number of CPUs for each nested ESXi host"
  type        = number
  default     = 8
}

variable "esxi_num_cores_per_socket" {
  description = "Number of cores per socket for nested ESXi"
  type        = number
  default     = 4
}

variable "esxi_memory_gb" {
  description = "Memory in GB for each nested ESXi host"
  type        = number
  default     = 64
}

variable "esxi_boot_disk_size_gb" {
  description = "Boot disk size in GB for nested ESXi"
  type        = number
  default     = 32
}

variable "esxi_cache_disk_size_gb" {
  description = "Cache disk size in GB for vSAN (SSD)"
  type        = number
  default     = 100
}

variable "esxi_capacity_disk_size_gb" {
  description = "Capacity disk size in GB for vSAN (HDD)"
  type        = number
  default     = 200
}

variable "esxi_root_password" {
  description = "Root password for nested ESXi hosts"
  type        = string
  sensitive   = true
}

variable "esxi_management_network" {
  description = "Management network for ESXi hosts"
  type        = string
}

# Cloud Builder Configuration
variable "deploy_cloud_builder" {
  description = "Whether to deploy Cloud Builder VM"
  type        = bool
  default     = true
}

variable "cloud_builder_ova_path" {
  description = "Path to Cloud Builder OVA"
  type        = string
  default     = ""
}

variable "cloud_builder_hostname" {
  description = "Hostname for Cloud Builder"
  type        = string
  default     = "cloudbuilder"
}

variable "cloud_builder_ip" {
  description = "IP address for Cloud Builder"
  type        = string
  default     = ""
}

variable "cloud_builder_netmask" {
  description = "Netmask for Cloud Builder"
  type        = string
  default     = "24"
}

variable "cloud_builder_gateway" {
  description = "Gateway for Cloud Builder"
  type        = string
  default     = ""
}

variable "cloud_builder_num_cpus" {
  description = "Number of CPUs for Cloud Builder"
  type        = number
  default     = 4
}

variable "cloud_builder_memory_gb" {
  description = "Memory in GB for Cloud Builder"
  type        = number
  default     = 18
}

variable "cloud_builder_root_password" {
  description = "Root password for Cloud Builder"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloud_builder_admin_password" {
  description = "Admin password for Cloud Builder"
  type        = string
  sensitive   = true
  default     = ""
}

# Network Configuration
variable "create_vcf_networks" {
  description = "Whether to create VCF port groups"
  type        = bool
  default     = true
}

variable "vcf_vlan_ids" {
  description = "VLAN IDs for VCF networks"
  type = object({
    management   = number
    vmotion      = number
    vsan         = number
    nsx_tep      = number
    nsx_edge_tep = number
    vm_network   = number
  })
  default = {
    management   = 100
    vmotion      = 101
    vsan         = 102
    nsx_tep      = 103
    nsx_edge_tep = 104
    vm_network   = 105
  }
}

variable "vcf_networks" {
  description = "Network configuration for VCF VLANs"
  type = object({
    management = object({
      network = string
      netmask = string
      gateway = string
    })
    vmotion = object({
      network = string
      netmask = string
    })
    vsan = object({
      network = string
      netmask = string
    })
    nsx_tep = object({
      network = string
      netmask = string
    })
    nsx_edge_tep = object({
      network = string
      netmask = string
    })
    vm_network = object({
      network = string
      netmask = string
      gateway = string
    })
  })
  default = {
    management = {
      network = "192.168.100.0"
      netmask = "24"
      gateway = "192.168.100.1"
    }
    vmotion = {
      network = "192.168.101.0"
      netmask = "24"
    }
    vsan = {
      network = "192.168.102.0"
      netmask = "24"
    }
    nsx_tep = {
      network = "192.168.103.0"
      netmask = "24"
    }
    nsx_edge_tep = {
      network = "192.168.104.0"
      netmask = "24"
    }
    vm_network = {
      network = "192.168.105.0"
      netmask = "24"
      gateway = "192.168.105.1"
    }
  }
}

variable "esxi_management_ips" {
  description = "List of static IPs for ESXi management interfaces"
  type        = list(string)
  default     = []
}

variable "dns_servers" {
  description = "DNS servers for VCF environment"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "ntp_servers" {
  description = "NTP servers for VCF environment"
  type        = list(string)
  default     = ["pool.ntp.org"]
}

# Tags and Metadata
variable "environment" {
  description = "Environment tag (e.g., production, development, lab)"
  type        = string
  default     = "lab"
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
