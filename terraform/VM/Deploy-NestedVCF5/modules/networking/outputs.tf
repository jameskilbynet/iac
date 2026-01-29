output "management_port_group_key" {
  description = "Management port group key"
  value       = vsphere_host_port_group.management.key
}

output "vmotion_port_group_key" {
  description = "vMotion port group key"
  value       = vsphere_host_port_group.vmotion.key
}

output "vsan_port_group_key" {
  description = "vSAN port group key"
  value       = vsphere_host_port_group.vsan.key
}

output "nsx_tep_port_group_key" {
  description = "NSX TEP port group key"
  value       = vsphere_host_port_group.nsx_tep.key
}

output "nsx_edge_tep_port_group_key" {
  description = "NSX Edge TEP port group key"
  value       = vsphere_host_port_group.nsx_edge_tep.key
}

output "vm_network_port_group_key" {
  description = "VM Network port group key"
  value       = vsphere_host_port_group.vm_network.key
}
