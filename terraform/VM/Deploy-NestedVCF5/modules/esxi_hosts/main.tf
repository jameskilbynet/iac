# Deploy nested ESXi VM
resource "vsphere_virtual_machine" "esxi" {
  name             = "${var.hostname}.${var.domain}"
  resource_pool_id = var.resource_pool_id
  datastore_id     = var.datastore_id
  folder           = var.folder_path

  num_cpus               = var.num_cpus
  num_cores_per_socket   = var.num_cores_per_socket
  memory                 = var.memory_mb
  guest_id               = "vmkernel7Guest"
  firmware               = "efi"
  
  # Enable nested virtualization
  nested_hv_enabled      = true
  
  # CPU performance counters for nested virtualization
  cpu_performance_counters_enabled = true

  # Network interface for management
  network_interface {
    network_id   = var.network_id
    adapter_type = "vmxnet3"
  }

  # Boot disk
  disk {
    label            = "disk0"
    size             = var.boot_disk_size_gb
    thin_provisioned = true
    unit_number      = 0
  }

  # vSAN cache disk (SSD)
  disk {
    label            = "disk1"
    size             = var.cache_disk_size_gb
    thin_provisioned = true
    unit_number      = 1
  }

  # vSAN capacity disk (HDD)
  disk {
    label            = "disk2"
    size             = var.capacity_disk_size_gb
    thin_provisioned = true
    unit_number      = 2
  }

  # Advanced options for nested ESXi
  extra_config = {
    "guestinfo.hostname"  = var.hostname
    "guestinfo.ipaddress" = var.management_ip
    "guestinfo.netmask"   = var.management_netmask
    "guestinfo.gateway"   = var.gateway
    "guestinfo.dns"       = join(",", var.dns_servers)
    "guestinfo.domain"    = var.domain
    "guestinfo.password"  = var.root_password
  }

  lifecycle {
    ignore_changes = [
      annotation,
      vapp
    ]
  }
}
