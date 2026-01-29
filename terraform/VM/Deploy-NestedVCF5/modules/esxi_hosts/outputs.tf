output "id" {
  description = "ESXi VM ID"
  value       = vsphere_virtual_machine.esxi.id
}

output "name" {
  description = "ESXi VM name"
  value       = vsphere_virtual_machine.esxi.name
}

output "default_ip_address" {
  description = "ESXi default IP address"
  value       = vsphere_virtual_machine.esxi.default_ip_address
}

output "guest_ip_addresses" {
  description = "All guest IP addresses"
  value       = vsphere_virtual_machine.esxi.guest_ip_addresses
}
