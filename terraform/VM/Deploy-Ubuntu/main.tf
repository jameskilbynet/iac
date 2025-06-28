terraform {
  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = ">= 2.13.0"
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
data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_datastore" "datastore" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_folder" "vm_folder" {
  path          = var.vm_folder
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Deploy Ubuntu VM from template
resource "vsphere_virtual_machine" "ubuntu_vm" {
  name             = var.vm_name
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = data.vsphere_folder.vm_folder.path

  num_cpus = var.num_cpus
  memory   = var.memory
  guest_id = data.vsphere_virtual_machine.template.guest_id

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = "vmxnet3"
  }

  # Clone from template
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    # Customize the VM if customization variables are provided
    dynamic "customize" {
      for_each = var.customize_vm ? [1] : []
      content {
        linux_options {
          host_name = var.hostname
          domain    = var.domain
        }

        network_interface {
          ipv4_address = var.ipv4_address
          ipv4_netmask = var.ipv4_netmask
        }

        ipv4_gateway = var.ipv4_gateway
        dns_server_list = var.dns_servers
      }
    }
  }

  # Disk configuration - clone the template's disk
  dynamic "disk" {
    for_each = data.vsphere_virtual_machine.template.disks
    content {
      label            = "disk${disk.key}"
      size             = var.disk_size != null ? var.disk_size : disk.value.size
      unit_number      = disk.key
      thin_provisioned = disk.value.thin_provisioned
    }
  }

  # Wait for guest IP
  wait_for_guest_ip_timeout = var.wait_for_guest_ip_timeout
  wait_for_guest_net_timeout = var.wait_for_guest_net_timeout

  # Ignore changes to vApp properties to prevent Terraform from resetting them
  lifecycle {
    ignore_changes = [
      vapp
    ]
  }
} 