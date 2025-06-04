# Terraform configuration for deploying a Photon VM from an OVA in vSphere Content Library

terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = ">= 2.2.0"
    }
  }
  required_version = ">= 1.0.0"
}

# Configure the vSphere Provider
provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}

# Data sources to fetch vSphere infrastructure details
data "vsphere_datacenter" "datacenter" {
  name = var.data_center
}

data "vsphere_datastore" "datastore" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_resource_pool" "resource_pool" {
  name          = var.resource_pool
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "network" {
  name          = var.network_name
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_content_library" "library" {
  name = var.content_library_name
}

data "vsphere_content_library_item" "photon_ova" {
  name       = var.content_library_item_name
  type       = "ovf"
  library_id = data.vsphere_content_library.library.id
}

# Deploy Photon VM from Content Library OVA
resource "vsphere_virtual_machine" "photon_vm" {
  name             = var.vm_name
  resource_pool_id = data.vsphere_resource_pool.resource_pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = var.vm_folder
  num_cpus         = 2
  memory           = 2048
  guest_id         = "other3xLinux64Guest"

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  disk {
    label            = "disk0"
    size             = 16
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_content_library_item.photon_ova.id
    customize {
      linux_options {
        host_name = var.vm_hostname
        domain    = var.domain
      }
      network_interface {
        ipv4_address = var.ipv4_address
        ipv4_netmask = 24
      }
      ipv4_gateway = var.ipv4_gateway
      dns_server_list = [var.dns_server]
    }
  }

  # Ignore changes to vApp properties to prevent Terraform from resetting them
  lifecycle {
    ignore_changes = [
      vapp
    ]
  }
}