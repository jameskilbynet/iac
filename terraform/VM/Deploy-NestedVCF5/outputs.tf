# Resource Pool Outputs
output "resource_pool_id" {
  description = "Resource pool ID for nested VCF"
  value       = module.resource_pool.id
}

output "resource_pool_name" {
  description = "Resource pool name"
  value       = module.resource_pool.name
}

# ESXi Hosts Outputs
output "esxi_host_names" {
  description = "Names of deployed ESXi hosts"
  value       = [for host in module.esxi_hosts : host.name]
}

output "esxi_host_ips" {
  description = "IP addresses of deployed ESXi hosts"
  value       = [for host in module.esxi_hosts : host.default_ip_address]
}

output "esxi_host_ids" {
  description = "IDs of deployed ESXi hosts"
  value       = [for host in module.esxi_hosts : host.id]
}

# Cloud Builder Outputs
output "cloud_builder_name" {
  description = "Cloud Builder VM name"
  value       = var.deploy_cloud_builder ? module.cloud_builder[0].name : null
}

output "cloud_builder_ip" {
  description = "Cloud Builder IP address"
  value       = var.deploy_cloud_builder ? module.cloud_builder[0].default_ip_address : null
}

output "cloud_builder_id" {
  description = "Cloud Builder VM ID"
  value       = var.deploy_cloud_builder ? module.cloud_builder[0].id : null
}

# VCF Folder Output
output "vcf_folder_path" {
  description = "Path to VCF VM folder"
  value       = vsphere_folder.vcf_folder.path
}

# Network Configuration Summary
output "vcf_network_summary" {
  description = "Summary of VCF network configuration"
  value = {
    management_vlan   = var.vcf_vlan_ids.management
    vmotion_vlan      = var.vcf_vlan_ids.vmotion
    vsan_vlan         = var.vcf_vlan_ids.vsan
    nsx_tep_vlan      = var.vcf_vlan_ids.nsx_tep
    nsx_edge_tep_vlan = var.vcf_vlan_ids.nsx_edge_tep
    vm_network_vlan   = var.vcf_vlan_ids.vm_network
  }
}

# Deployment Summary
output "deployment_summary" {
  description = "Summary of nested VCF deployment"
  value = {
    esxi_host_count = var.esxi_count
    domain          = var.esxi_domain
    resource_pool   = var.resource_pool_name
    cloud_builder   = var.deploy_cloud_builder
  }
}
