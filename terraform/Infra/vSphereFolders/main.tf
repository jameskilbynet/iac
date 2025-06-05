terraform {
  required_providers {
    vsphere = {
      source = "vmware/vsphere"
      version = "2.7.0"
    }
  }
}

provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {}

resource "vsphere_folder" "parent" {
  path          = "Production"
  type          = "vm"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_folder" "folder" {
  path          = "${vsphere_folder.parent.path}/Active Directory"
  type          = "vm"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_folder" "iac" {
  path          = "${vsphere_folder.parent.path}/IAC"
  type          = "vm"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_folder" "aria" {
  path          = "${vsphere_folder.parent.path}/Aria"
  type          = "vm"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_folder" "Horizon" {
  path          = "${vsphere_folder.parent.path}/Horizon"
  type          = "vm"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_folder" "test" {
  path          = "test"
  type          = "vm"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_folder" "parent" {
  path          = "Docker"
  type          = "vm"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_folder" "holodeck" {
  path          = "${vsphere_folder.test.path}/HoloDeck"
  type          = "vm"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}
