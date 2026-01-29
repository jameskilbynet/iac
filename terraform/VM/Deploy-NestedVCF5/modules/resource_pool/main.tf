resource "vsphere_resource_pool" "pool" {
  name                    = var.name
  parent_resource_pool_id = var.cluster_id

  cpu_share_level         = "normal"
  cpu_reservation         = var.cpu_reservation
  cpu_expandable          = true

  memory_share_level      = "normal"
  memory_reservation      = var.memory_reservation
  memory_expandable       = true
}
