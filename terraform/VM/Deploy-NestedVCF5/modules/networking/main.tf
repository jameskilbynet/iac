# Get the first host in the cluster to attach port groups
data "vsphere_host" "host" {
  datacenter_id = var.datacenter_id
}

# Create VCF Management port group
resource "vsphere_host_port_group" "management" {
  name                = "VCF-Management"
  host_system_id      = data.vsphere_host.host.id
  virtual_switch_name = "vSwitch0"

  vlan_id = var.vlan_ids.management

  allow_promiscuous      = false
  allow_forged_transmits = false
  allow_mac_changes      = false
}

# Create VCF vMotion port group
resource "vsphere_host_port_group" "vmotion" {
  name                = "VCF-vMotion"
  host_system_id      = data.vsphere_host.host.id
  virtual_switch_name = "vSwitch0"

  vlan_id = var.vlan_ids.vmotion

  allow_promiscuous      = false
  allow_forged_transmits = false
  allow_mac_changes      = false
}

# Create VCF vSAN port group
resource "vsphere_host_port_group" "vsan" {
  name                = "VCF-vSAN"
  host_system_id      = data.vsphere_host.host.id
  virtual_switch_name = "vSwitch0"

  vlan_id = var.vlan_ids.vsan

  allow_promiscuous      = false
  allow_forged_transmits = false
  allow_mac_changes      = false
}

# Create VCF NSX TEP port group
resource "vsphere_host_port_group" "nsx_tep" {
  name                = "VCF-NSX-TEP"
  host_system_id      = data.vsphere_host.host.id
  virtual_switch_name = "vSwitch0"

  vlan_id = var.vlan_ids.nsx_tep

  allow_promiscuous      = false
  allow_forged_transmits = false
  allow_mac_changes      = false
}

# Create VCF NSX Edge TEP port group
resource "vsphere_host_port_group" "nsx_edge_tep" {
  name                = "VCF-NSX-Edge-TEP"
  host_system_id      = data.vsphere_host.host.id
  virtual_switch_name = "vSwitch0"

  vlan_id = var.vlan_ids.nsx_edge_tep

  allow_promiscuous      = false
  allow_forged_transmits = false
  allow_mac_changes      = false
}

# Create VCF VM Network port group
resource "vsphere_host_port_group" "vm_network" {
  name                = "VCF-VM-Network"
  host_system_id      = data.vsphere_host.host.id
  virtual_switch_name = "vSwitch0"

  vlan_id = var.vlan_ids.vm_network

  allow_promiscuous      = false
  allow_forged_transmits = false
  allow_mac_changes      = false
}
