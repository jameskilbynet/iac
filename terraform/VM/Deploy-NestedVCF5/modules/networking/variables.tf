variable "datacenter_id" {
  description = "vSphere datacenter ID"
  type        = string
}

variable "cluster_id" {
  description = "vSphere cluster ID"
  type        = string
}

variable "vlan_ids" {
  description = "VLAN IDs for VCF networks"
  type = object({
    management   = number
    vmotion      = number
    vsan         = number
    nsx_tep      = number
    nsx_edge_tep = number
    vm_network   = number
  })
}
