terraform {
  required_version = ">= 1.0.0"

  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = ">= 2.13.0"
    }
  }
}
