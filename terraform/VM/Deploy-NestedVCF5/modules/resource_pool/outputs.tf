output "id" {
  description = "Resource pool ID"
  value       = vsphere_resource_pool.pool.id
}

output "name" {
  description = "Resource pool name"
  value       = vsphere_resource_pool.pool.name
}
