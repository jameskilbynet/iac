output "vm_name" {
  description = "Name of the deployed SQL Server VM"
  value       = vsphere_virtual_machine.sql_server.name
}

output "vm_id" {
  description = "ID of the deployed SQL Server VM"
  value       = vsphere_virtual_machine.sql_server.id
}

output "vm_uuid" {
  description = "UUID of the deployed SQL Server VM"
  value       = vsphere_virtual_machine.sql_server.uuid
}

output "default_ip_address" {
  description = "Default IP address of the SQL Server VM"
  value       = vsphere_virtual_machine.sql_server.default_ip_address
}

output "guest_ip_addresses" {
  description = "All IP addresses of the SQL Server VM"
  value       = vsphere_virtual_machine.sql_server.guest_ip_addresses
}

output "num_cpus" {
  description = "Number of CPUs allocated"
  value       = vsphere_virtual_machine.sql_server.num_cpus
}

output "memory" {
  description = "Memory in MB allocated"
  value       = vsphere_virtual_machine.sql_server.memory
}

output "disk_configuration" {
  description = "Disk configuration summary"
  value = {
    os_disk    = "${var.os_disk_size} GB (C:)"
    data_disk  = "${var.sql_data_disk_size} GB (D:)"
    log_disk   = "${var.sql_log_disk_size} GB (E:)"
    tempdb_disk = "${var.tempdb_disk_size} GB (T:)"
    backup_disk = var.backup_disk_size > 0 ? "${var.backup_disk_size} GB (B:)" : "Not configured"
  }
}
