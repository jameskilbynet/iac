# Ubuntu 24.04 vSphere Packer Build

This Packer configuration builds an Ubuntu 24.04 LTS Server VM template on VMware vSphere with open-vm-tools.

## Features

- **Ubuntu 24.04 LTS** server with latest packages
- **open-vm-tools** for optimal vSphere integration
- **Automated installation** using Ubuntu's autoinstall
- **Password authentication** with username `ubuntu` and password `ubuntu`
- **Passwordless sudo** configured for the ubuntu user
- **Template creation** for easy VM deployment

## Prerequisites

1. **Packer** installed (>= 1.8.0)
2. **vSphere environment** with appropriate permissions
3. **Network connectivity** from your machine to vSphere

## Quick Start

1. **Initialize Packer plugins:**
   ```bash
   packer init ubuntu-vsphere.pkr.hcl
   ```

2. **Copy and configure variables:**
   ```bash
   cp variables.pkrvars.hcl.example variables.pkrvars.hcl
   # Edit variables.pkrvars.hcl with your vSphere details
   ```

3. **Validate configuration:**
   ```bash
   packer validate -var-file="variables.pkrvars.hcl" ubuntu-vsphere.pkr.hcl
   ```

4. **Build the template:**
   ```bash
   packer build -var-file="variables.pkrvars.hcl" ubuntu-vsphere.pkr.hcl
   ```

## Configuration

### Required Variables

Update `variables.pkrvars.hcl` with your environment:

- `vsphere_server` - vCenter hostname/IP
- `vsphere_username` - vCenter username
- `vsphere_password` - vCenter password
- `vsphere_datacenter` - Datacenter name
- `vsphere_cluster` - Cluster name
- `vsphere_datastore` - Datastore name
- `vsphere_network` - Network name

### Optional Variables

- `vsphere_folder` - VM folder path
- `vsphere_resource_pool` - Resource pool name
- `vm_name` - Template name
- `vm_memory` - RAM in MB (default: 2048)
- `vm_cpus` - CPU count (default: 2)
- `disk_size` - Disk size in MB (default: 20480)

## Default Credentials

- **Username:** ubuntu
- **Password:** ubuntu
- **SSH:** Enabled with password authentication
- **Sudo:** Passwordless sudo configured

## Installed Software

- Ubuntu 24.04 LTS Server
- OpenSSH Server
- open-vm-tools
- Basic utilities (curl, wget, vim, git, htop, tree)

## File Structure

```
.
├── ubuntu-vsphere.pkr.hcl      # Main Packer configuration
├── variables.pkrvars.hcl.example # Variables template
├── http/
│   ├── user-data               # Ubuntu autoinstall config
│   └── meta-data              # Required empty file
└── README.md                  # This file
```

## Troubleshooting

1. **Check network connectivity** to vSphere from your machine
2. **Verify vSphere permissions** for the user account
3. **Ensure datastore has sufficient space** (at least 25GB)
4. **Check vSphere network configuration** allows DHCP

## Security Notes

- Change default password after template deployment
- Consider using SSH keys for production deployments
- Set `insecure_connection = false` in production with proper SSL certificates

## Support

This configuration has been tested with:
- Ubuntu 24.04.1 LTS
- VMware vSphere 7.0+
- Packer 1.8.0+
