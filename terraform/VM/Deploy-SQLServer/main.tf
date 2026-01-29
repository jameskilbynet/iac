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
  name          = var.vm_folder
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Deploy Windows SQL Server VM from template
resource "vsphere_virtual_machine" "sql_server" {
  name             = var.vm_name
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = data.vsphere_folder.vm_folder.path

  # CPU and Memory configuration
  num_cpus               = var.num_cpus
  num_cores_per_socket   = var.cores_per_socket
  memory                 = var.memory
  memory_reservation     = var.memory_reservation_enabled ? var.memory : 0
  cpu_hot_add_enabled    = var.cpu_hot_add_enabled
  memory_hot_add_enabled = var.memory_hot_add_enabled
  guest_id               = data.vsphere_virtual_machine.template.guest_id

  # Enable CPU and memory reservations for production SQL workloads
  cpu_reservation = var.cpu_reservation_mhz

  # SCSI controller configuration for SQL Server best practices
  scsi_type = var.scsi_controller_type

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = "vmxnet3"
  }

  # Clone from template
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    # Customize the VM with Windows-specific settings
    customize {
      windows_options {
        computer_name         = var.hostname
        workgroup             = var.workgroup
        admin_password        = var.admin_password
        auto_logon            = false
        auto_logon_count      = 1
        time_zone             = var.timezone
        run_once_command_list = var.run_once_commands
      }

      network_interface {
        ipv4_address = var.ipv4_address
        ipv4_netmask = var.ipv4_netmask
      }

      ipv4_gateway    = var.ipv4_gateway
      dns_server_list = var.dns_servers
    }
  }

  # Disk 0: OS Disk (C:)
  disk {
    label            = "disk0"
    size             = var.os_disk_size
    unit_number      = 0
    thin_provisioned = var.thin_provisioned
    eagerly_scrub    = var.eagerly_scrub
  }

  # Disk 1: SQL Data Disk (D:)
  # Separate disk for SQL data files following best practices
  disk {
    label            = "disk1"
    size             = var.sql_data_disk_size
    unit_number      = 1
    thin_provisioned = var.thin_provisioned
    eagerly_scrub    = var.eagerly_scrub
  }

  # Disk 2: SQL Log Disk (E:)
  # Separate disk for SQL log files for better I/O performance
  disk {
    label            = "disk2"
    size             = var.sql_log_disk_size
    unit_number      = 2
    thin_provisioned = var.thin_provisioned
    eagerly_scrub    = var.eagerly_scrub
  }

  # Disk 3: TempDB Disk (T:)
  # Dedicated disk for TempDB to avoid I/O contention
  disk {
    label            = "disk3"
    size             = var.tempdb_disk_size
    unit_number      = 3
    thin_provisioned = var.thin_provisioned
    eagerly_scrub    = var.eagerly_scrub
  }

  # Disk 4: SQL Backup Disk (B:) - Optional
  dynamic "disk" {
    for_each = var.backup_disk_size > 0 ? [1] : []
    content {
      label            = "disk4"
      size             = var.backup_disk_size
      unit_number      = 4
      thin_provisioned = var.thin_provisioned
      eagerly_scrub    = var.eagerly_scrub
    }
  }

  # Advanced options for SQL Server performance
  enable_disk_uuid            = true
  hv_mode                     = "hvAuto"
  ept_rvi_mode                = "automatic"
  nested_hv_enabled           = false
  enable_logging              = false
  swap_placement_policy       = "vmDirectory"
  memory_share_level          = var.memory_share_level
  cpu_share_level             = var.cpu_share_level

  # Latency sensitivity for production SQL workloads
  latency_sensitivity = var.latency_sensitivity

  # Wait for guest IP
  wait_for_guest_ip_timeout  = var.wait_for_guest_ip_timeout
  wait_for_guest_net_timeout = var.wait_for_guest_net_timeout

  # Ignore changes to certain properties
  lifecycle {
    ignore_changes = [
      vapp
    ]
  }
}
