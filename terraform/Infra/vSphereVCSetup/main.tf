provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}

resource "vsphere_datacenter" "prod_datacenter" {
  name = "uk-bhr-p-dc-1"
}

variable "datacenter" {
  default = "uk-bhr-p-dc-1"
}



data "vsphere_datacenter" "datacenter" {
  name = var.datacenter
}


resource "vsphere_compute_cluster" "compute_cluster" {
  name            = "uk-bhr-p-cl-1"
  datacenter_id   = data.vsphere_datacenter.datacenter.id


  drs_enabled          = true
  drs_automation_level = "fullyAutomated"

  ha_enabled = true
}

resource "vsphere_compute_cluster" "compute_cluster2" {
  name            = "uk-bhr-p-cl-2"
  datacenter_id   = data.vsphere_datacenter.datacenter.id


  drs_enabled          = true
  drs_automation_level = "fullyAutomated"

  ha_enabled = true
}
