output "vm_id" {
  description = "The ID of the deployed Ubuntu VM"
  value       = vsphere_virtual_machine.ubuntu_vm.id
}

output "vm_name" {
  description = "The name of the deployed Ubuntu VM"
  value       = vsphere_virtual_machine.ubuntu_vm.name
}

output "vm_guest_id" {
  description = "The guest ID of the deployed Ubuntu VM"
  value       = vsphere_virtual_machine.ubuntu_vm.guest_id
}

output "vm_moid" {
  description = "The managed object ID of the deployed Ubuntu VM"
  value       = vsphere_virtual_machine.ubuntu_vm.moid
}

output "vm_uuid" {
  description = "The UUID of the deployed Ubuntu VM"
  value       = vsphere_virtual_machine.ubuntu_vm.uuid
}

output "vm_guest_ip_addresses" {
  description = "The guest IP addresses of the deployed Ubuntu VM"
  value       = vsphere_virtual_machine.ubuntu_vm.guest_ip_addresses
}

output "vm_default_ip_address" {
  description = "The default IP address of the deployed Ubuntu VM"
  value       = vsphere_virtual_machine.ubuntu_vm.default_ip_address
}

output "vm_power_state" {
  description = "The power state of the deployed Ubuntu VM"
  value       = vsphere_virtual_machine.ubuntu_vm.power_state
}

output "vm_resource_pool_id" {
  description = "The resource pool ID of the deployed Ubuntu VM"
  value       = vsphere_virtual_machine.ubuntu_vm.resource_pool_id
}

output "vm_datastore_id" {
  description = "The datastore ID of the deployed Ubuntu VM"
  value       = vsphere_virtual_machine.ubuntu_vm.datastore_id
}

output "vm_folder" {
  description = "The folder path of the deployed Ubuntu VM"
  value       = vsphere_virtual_machine.ubuntu_vm.folder
} 