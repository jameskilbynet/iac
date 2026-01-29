output "id" {
  description = "Cloud Builder VM ID"
  value       = vsphere_virtual_machine.cloud_builder.id
}

output "name" {
  description = "Cloud Builder VM name"
  value       = vsphere_virtual_machine.cloud_builder.name
}

output "default_ip_address" {
  description = "Cloud Builder default IP address"
  value       = vsphere_virtual_machine.cloud_builder.default_ip_address
}
