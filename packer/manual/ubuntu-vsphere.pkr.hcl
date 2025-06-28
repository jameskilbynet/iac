packer {
  required_version = ">= 1.8.0"
  required_plugins {
    vsphere = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/vsphere"
    }
  }
}

# Variables
variable "ubuntu_iso_url" {
  type        = string
  default     = "https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso"
  description = "Ubuntu ISO download URL"
}

variable "ubuntu_iso_checksum" {
  type        = string
  default     = "e240e4b801f7bb68c20d1356b60968ad0c33a41d00d828e74ceb3364a0317be9"
  description = "Ubuntu ISO checksum"
}

variable "vm_name" {
  type        = string
  default     = "ubuntu-24.04-server"
  description = "VM name"
}

variable "vm_memory" {
  type        = number
  default     = 2048
  description = "VM memory in MB"
}

variable "vm_cpus" {
  type        = number
  default     = 2
  description = "Number of CPUs"
}

variable "disk_size" {
  type        = number
  default     = 20480
  description = "Disk size in MB"
}

variable "ssh_username" {
  type        = string
  default     = "ubuntu"
  description = "SSH username"
}

variable "vsphere_server" {
  type        = string
  description = "vSphere server hostname or IP"
}

variable "vsphere_username" {
  type        = string
  description = "vSphere username"
}

variable "vsphere_password" {
  type        = string
  description = "vSphere password"
  sensitive   = true
}

variable "vsphere_datacenter" {
  type        = string
  description = "vSphere datacenter name"
}

variable "vsphere_cluster" {
  type        = string
  description = "vSphere cluster name"
}

variable "vsphere_datastore" {
  type        = string
  description = "vSphere datastore name"
}

variable "vsphere_network" {
  type        = string
  description = "vSphere network name"
}

variable "vsphere_folder" {
  type        = string
  description = "vSphere folder path for VM"
  default     = ""
}

variable "vsphere_resource_pool" {
  type        = string
  description = "vSphere resource pool name"
  default     = ""
}

# Local variables
locals {
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds='nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/' ",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]
}

# Source configuration
source "vsphere-iso" "ubuntu" {
  # vSphere Connection
  vcenter_server      = var.vsphere_server
  username            = var.vsphere_username
  password            = var.vsphere_password
  insecure_connection = true

  # vSphere Location
  datacenter     = var.vsphere_datacenter
  cluster        = var.vsphere_cluster
  datastore      = var.vsphere_datastore
  folder         = var.vsphere_folder
  resource_pool  = var.vsphere_resource_pool

  # VM Configuration
  vm_name       = var.vm_name
  guest_os_type = "ubuntu64Guest"
  vm_version    = 21
  CPUs          = var.vm_cpus
  cpu_cores     = 1
  RAM           = var.vm_memory
  RAM_reserve_all = false

  # Network Configuration
  network_adapters {
    network      = var.vsphere_network
    network_card = "vmxnet3"
  }

  # Storage Configuration
  storage {
    disk_size             = var.disk_size
    disk_thin_provisioned = true
  }

  # ISO Configuration
  iso_url      = var.ubuntu_iso_url
  iso_checksum = "sha256:${var.ubuntu_iso_checksum}"

  # Boot Configuration
  boot_command = local.boot_command
  boot_wait    = "5s"

  # HTTP Server for autoinstall
  http_directory = "http"

  # SSH Configuration
  ssh_username     = var.ssh_username
  ssh_password     = "ubuntu"  # Password fallback
  ssh_timeout      = "45m"
  ssh_port         = 22
  ssh_wait_timeout = "45m"

  # Shutdown
  shutdown_command = "sudo shutdown -P now"

  # Template Creation
  convert_to_template = true
  create_snapshot     = false
}

# Build configuration
build {
  name = "ubuntu-server"
  sources = [
    "source.vsphere-iso.ubuntu"
  ]

  # Wait for system to be ready
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done"
    ]
  }

  # Update system
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y open-vm-tools"
    ]
  }

  # Enable open-vm-tools
  provisioner "shell" {
    inline = [
      "sudo systemctl enable open-vm-tools",
      "sudo systemctl start open-vm-tools"
    ]
  }


}

