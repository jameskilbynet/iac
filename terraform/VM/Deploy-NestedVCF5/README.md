# Nested VMware Cloud Foundation 5 Terraform Deployment

Automated deployment of a nested VMware Cloud Foundation (VCF) 5 environment using Terraform. This configuration deploys multiple nested ESXi hosts with vSAN storage, Cloud Builder VM, and all required networking for a complete VCF lab environment.

## Overview

This Terraform configuration automates the deployment of:
- **Dedicated Resource Pool** for VCF resources
- **Multiple Nested ESXi Hosts** (minimum 4) with nested virtualization enabled
- **vSAN Storage Configuration** with cache and capacity disks
- **VCF Network Port Groups** for all required VLANs
- **Cloud Builder VM** for VCF management domain deployment
- **VM Folder Structure** for organized resource management

## Architecture

### Nested ESXi Hosts
Each nested ESXi host includes:
- **CPU**: 8 vCPUs (configurable) with nested virtualization enabled
- **Memory**: 64GB (configurable)
- **Storage**:
  - Boot disk: 32GB
  - vSAN cache disk (SSD): 100GB
  - vSAN capacity disk (HDD): 200GB
- **Network**: vmxnet3 adapter on management network

### VCF Networks
The following VLANs are configured (aligned with your MikroTik VCF setup):
- **VLAN 100**: Management Network (192.168.100.0/24)
- **VLAN 101**: vMotion Network (192.168.101.0/24)
- **VLAN 102**: vSAN Network (192.168.102.0/24)
- **VLAN 103**: NSX Tunnel Endpoint (192.168.103.0/24)
- **VLAN 104**: NSX Edge Tunnel Endpoint (192.168.104.0/24)
- **VLAN 105**: VM Network (192.168.105.0/24)

## Prerequisites

### Physical Infrastructure
- **vCenter Server**: uk-bhr-p-vc-1.jameskilby.cloud (or your vCenter)
- **ESXi Cluster**: With sufficient resources for nested VMs
- **Datastore**: Sufficient space for all VMs and disks
- **Network**: VLANs configured on MikroTik switches (see `../../../scripts/mikrotik/README.md`)

### Software Requirements
- **Terraform**: >= 1.0.0
- **vSphere Provider**: >= 2.13.0
- **Nested ESXi OVA**: Download from [William Lam's repository](https://williamlam.com/nested-virtualization)
- **Cloud Builder OVA**: Download from VMware Customer Connect

### Resource Requirements
For a 4-host nested VCF deployment:
- **Total CPU**: ~32 vCPUs (8 per host)
- **Total Memory**: ~256GB RAM (64GB per host)
- **Total Storage**: ~1.3TB
  - ESXi VMs: ~528GB per host × 4 = ~2.1TB
  - Cloud Builder: ~300GB
  - Overhead: ~20%

### Network Requirements
Ensure your MikroTik switches are configured with VCF VLANs. If not configured, run:
```bash
cd ../../../scripts/mikrotik
./provision-mikrotik-vcf.sh
```

## Directory Structure

```
Deploy-NestedVCF5/
├── main.tf                      # Main configuration and module orchestration
├── variables.tf                 # Variable definitions
├── outputs.tf                   # Output definitions
├── terraform.tfvars.example     # Example configuration file
├── README.md                    # This file
└── modules/
    ├── resource_pool/           # Resource pool module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── esxi_hosts/              # Nested ESXi deployment module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── cloud_builder/           # Cloud Builder VM module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── networking/              # VCF networking module
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Quick Start

### 1. Download Required OVAs

**Nested ESXi OVA:**
```bash
# Download from William Lam's GitHub or VMware Flings
# Example: Nested_ESXi8.0u2_Appliance_Template_v1.ova
```

**Cloud Builder OVA:**
```bash
# Download from VMware Customer Connect
# Example: VMware-Cloud-Builder-5.2.0.0-23480823_OVF10.ova
```

### 2. Configure Terraform Variables

```bash
cd /Users/w20kilja/Github/iac/terraform/VM/Deploy-NestedVCF5
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

**Minimum required configuration:**
```hcl
vsphere_server   = "uk-bhr-p-vc-1.jameskilby.cloud"
vsphere_user     = "administrator@vsphere.local"
vsphere_password = "YourPasswordHere"

datastore  = "your-datastore-name"
network    = "VM Network"

esxi_ova_path           = "/path/to/Nested_ESXi8.0u2_Appliance_Template_v1.ova"
esxi_root_password      = "VMware1!"
esxi_management_network = "VCF-Management"

cloud_builder_ova_path       = "/path/to/VMware-Cloud-Builder-5.2.0.0-23480823_OVF10.ova"
cloud_builder_ip             = "192.168.100.50"
cloud_builder_gateway        = "192.168.100.1"
cloud_builder_root_password  = "VMware1!"
cloud_builder_admin_password = "VMware1!"

esxi_management_ips = [
  "192.168.100.11",
  "192.168.100.12",
  "192.168.100.13",
  "192.168.100.14"
]
```

### 3. Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan

# Deploy the environment
terraform apply
```

The deployment takes approximately **30-45 minutes** depending on your infrastructure.

### 4. Access Deployment Information

```bash
# View all outputs
terraform output

# View specific outputs
terraform output esxi_host_ips
terraform output cloud_builder_ip
```

## Post-Deployment Steps

### 1. Verify ESXi Hosts

SSH to each ESXi host and verify:
```bash
ssh root@192.168.100.11
esxcli system version get
esxcli network ip interface list
```

### 2. Access Cloud Builder

Open a browser and navigate to:
```
https://192.168.100.50
```

Default credentials:
- **Username**: admin
- **Password**: (as configured in terraform.tfvars)

### 3. Prepare VCF Deployment JSON

Create a VCF deployment JSON file for Cloud Builder. Example:
```json
{
  "sddcManagerSpec": {
    "hostname": "sddc-manager",
    "ipAddress": "192.168.100.60"
  },
  "esxiHosts": [
    {
      "hostname": "esxi-1.vcf.local",
      "ipAddress": "192.168.100.11"
    },
    {
      "hostname": "esxi-2.vcf.local",
      "ipAddress": "192.168.100.12"
    },
    {
      "hostname": "esxi-3.vcf.local",
      "ipAddress": "192.168.100.13"
    },
    {
      "hostname": "esxi-4.vcf.local",
      "ipAddress": "192.168.100.14"
    }
  ]
}
```

Refer to the [VMware Cloud Foundation documentation](https://docs.vmware.com/en/VMware-Cloud-Foundation/) for the complete deployment JSON schema.

### 4. Deploy VCF Management Domain

Use Cloud Builder to deploy the VCF management domain:
1. Upload your deployment JSON
2. Validate the configuration
3. Start the deployment
4. Monitor progress (takes 2-4 hours)

## Configuration Options

### Scaling ESXi Hosts

Change the number of ESXi hosts (minimum 4):
```hcl
esxi_count = 6  # Deploy 6 hosts instead of 4
```

### Adjusting Resources

Modify CPU and memory per host:
```hcl
esxi_num_cpus  = 12
esxi_memory_gb = 96
```

### Custom VLAN IDs

Change VLAN IDs to match your network:
```hcl
vcf_vlan_ids = {
  management   = 10
  vmotion      = 11
  vsan         = 12
  nsx_tep      = 13
  nsx_edge_tep = 14
  vm_network   = 15
}
```

### Disable Cloud Builder

Deploy only ESXi hosts without Cloud Builder:
```hcl
deploy_cloud_builder = false
```

### Disable Network Creation

If port groups already exist:
```hcl
create_vcf_networks = false
```

## Modules

### Resource Pool Module
Creates a dedicated resource pool for the nested VCF environment with configurable CPU and memory reservations.

**Inputs:**
- `name`: Resource pool name
- `cluster_id`: Parent cluster ID
- `cpu_reservation`: CPU reservation in MHz
- `memory_reservation`: Memory reservation in MB

### ESXi Hosts Module
Deploys nested ESXi VMs with nested virtualization enabled and vSAN storage disks.

**Key Features:**
- Nested HV enabled
- CPU performance counters enabled
- Three disks: boot, cache (SSD), capacity (HDD)
- Network customization via guestinfo properties

### Cloud Builder Module
Deploys the VCF Cloud Builder appliance from OVA with network customization.

**Key Features:**
- OVF deployment with property injection
- Static IP configuration
- DNS and gateway configuration
- Admin and root password setup

### Networking Module
Creates VCF-specific port groups on vSphere standard switches.

**Port Groups Created:**
- VCF-Management
- VCF-vMotion
- VCF-vSAN
- VCF-NSX-TEP
- VCF-NSX-Edge-TEP
- VCF-VM-Network

## Integration with Existing Infrastructure

This deployment integrates with:
- **MikroTik VCF Network Configuration**: See `../../../scripts/mikrotik/README.md`
- **VCF Offline Bundle Server**: See `../../../ansible/VCF/README.md`
- **vSphere Infrastructure**: See `../../Infra/README.md`

## Troubleshooting

### ESXi Hosts Not Booting
**Symptom**: ESXi VMs are stuck at BIOS or not booting
**Solution**:
- Verify nested virtualization is supported on your physical ESXi hosts
- Check that VT-x/AMD-V is enabled in BIOS
- Ensure `nested_hv_enabled = true` in the configuration

### Network Connectivity Issues
**Symptom**: VMs cannot communicate
**Solution**:
- Verify VLANs are configured on MikroTik switches
- Check port group VLAN IDs match MikroTik configuration
- Verify trunk ports are configured correctly

### Insufficient Resources
**Symptom**: "Insufficient resources" error during deployment
**Solution**:
- Check available CPU, memory, and storage on your cluster
- Reduce `esxi_count`, `esxi_num_cpus`, or `esxi_memory_gb`
- Enable DRS and set to fully automated

### Cloud Builder OVA Deployment Fails
**Symptom**: OVA deployment fails with network mapping error
**Solution**:
- Verify the OVA path is correct
- Check that the management network exists
- Review OVA network mapping in `modules/cloud_builder/main.tf`

### Static IPs Not Applied
**Symptom**: ESXi hosts get DHCP addresses instead of static IPs
**Solution**:
- Verify `esxi_management_ips` list has correct number of IPs
- Check that the nested ESXi OVA supports guestinfo properties
- Ensure DNS servers are reachable from management network

## Maintenance

### Adding More ESXi Hosts

```bash
# Edit terraform.tfvars
esxi_count = 6

# Add more IPs to the list
esxi_management_ips = [
  "192.168.100.11",
  "192.168.100.12",
  "192.168.100.13",
  "192.168.100.14",
  "192.168.100.15",
  "192.168.100.16"
]

# Apply changes
terraform apply
```

### Updating ESXi Configuration

To update existing ESXi host configuration:
1. Make changes to `terraform.tfvars`
2. Run `terraform plan` to review changes
3. Run `terraform apply`

**Note**: Some changes may require VM reboot or recreation.

### Destroying the Environment

```bash
# Destroy all resources
terraform destroy

# Destroy specific resources
terraform destroy -target=module.cloud_builder
```

**Warning**: This will permanently delete all VMs and configurations.

## Security Considerations

### Password Management
- **Never commit passwords** to version control
- Use environment variables or Terraform Cloud for sensitive values
- Consider using HashiCorp Vault for password management

### Network Isolation
- Deploy on isolated VLANs
- Use firewall rules to restrict access
- Implement NSX micro-segmentation in production

### Resource Limits
- Configure resource reservations to prevent over-commitment
- Set CPU and memory limits if sharing physical resources
- Monitor resource usage with vRealize Operations

## Performance Optimization

### vSAN Configuration
- Use SSD/NVMe for cache disks in production
- Configure vSAN deduplication and compression
- Monitor vSAN health after deployment

### Network Performance
- Use 10GbE networks for vSAN and vMotion in production
- Enable jumbo frames (MTU 9000) for storage networks
- Separate physical NICs for different traffic types

### CPU Optimization
- Enable CPU reservations for production workloads
- Use CPU affinity for critical VMs
- Monitor CPU ready time and co-stop metrics

## Additional Resources

- **VMware Cloud Foundation Documentation**: [docs.vmware.com/vcf](https://docs.vmware.com/en/VMware-Cloud-Foundation/)
- **VCF Planning and Prep Workbook**: Available on VMware Customer Connect
- **Nested Virtualization Guide**: [William Lam's Blog](https://williamlam.com/nested-virtualization)
- **Terraform vSphere Provider**: [registry.terraform.io/providers/hashicorp/vsphere](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs)
- **VMware Flings**: [flings.vmware.com](https://flings.vmware.com)

## Support

For issues related to:
- **Terraform Configuration**: Review this README and check logs
- **vSphere Provider**: See provider documentation
- **VMware Cloud Foundation**: Consult VMware documentation
- **Network Configuration**: See MikroTik VCF provisioning scripts

## License

This project follows the same license as the parent repository.
