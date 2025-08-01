terraform {
  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = ">= 2.2.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "vsphere" {
  user           = var.vsphere_user
  password       = var.vsphere_password
  vsphere_server = var.vsphere_server

  # If you're using a self-signed cert
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "datacenter_a" {
  name = "uk-bhr-p-dc-1"
}

data "vsphere_datastore" "publisher_datastore" {
  name          = "vsanDatastore"
  datacenter_id = data.vsphere_datacenter.datacenter_a.id
}

resource "vsphere_content_library" "publisher_content_library" {
  name            = "packer"
  description     = "A packer content library."
  storage_backing = [data.vsphere_datastore.publisher_datastore.id]
  publication {
    published = true
  }
}

resource "vsphere_content_library" "publisher_content_library2" {
  name            = "manualimages"
  description     = "handcutimages"
  storage_backing = [data.vsphere_datastore.publisher_datastore.id]
  publication {
    published = true
  }
}



