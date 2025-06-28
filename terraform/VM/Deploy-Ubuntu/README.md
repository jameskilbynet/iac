# Ubuntu VM Deployment

This Terraform configuration deploys Ubuntu virtual machines from existing vSphere templates with optional customization capabilities.

## Overview

This module provides a flexible way to provision Ubuntu VMs from templates in your vSphere environment. It supports both simple cloning and advanced customization including static IP configuration.

## Features

- **Template-based deployment**: Clone from existing Ubuntu templates
- **Flexible customization**: Optional static IP and hostname configuration
- **Resource management**: Configurable CPU, memory, and disk sizes
- **Network configuration**: Support for both DHCP and static IP addressing
- **Comprehensive outputs**: Detailed information about deployed VMs
- **Lifecycle management**: Proper handling of vApp properties

## Prerequisites

- **vSphere Environment**: ESXi host or vCenter server access
- **Ubuntu Template**: Existing Ubuntu VM template in vSphere
- **Terraform**: >= 1.0.0
- **vSphere Provider**: >= 2.13.0
- **Network Access**: Connectivity to vSphere management network

## Quick Start

### 1. Configure Variables

Copy the example variables file and customize it for your environment:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your vSphere details:

```hcl
# vSphere Connection
vsphere_user     = "administrator@vsphere.local"
vsphere_password = "your-password"
vsphere_server   = "vcenter.company.com"

# Infrastructure
datacenter = "Production-DC"
datastore  = "vsanDatastore"
cluster    = "Production-Cluster"
network    = "VM-Network"
vm_folder  = "Production/Ubuntu"

# VM Configuration
template_name = "ubuntu-22.04-template"
vm_name       = "web-server-01"
```

### 2. Deploy the VM

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy the VM
terraform apply
```

### 3. Access the VM

After deployment, you can access the VM using the IP address from the outputs:

```bash
terraform output vm_default_ip_address
```

## Configuration Options

### Basic Deployment

For a simple deployment without customization (uses DHCP):

```hcl
# terraform.tfvars
customize_vm = false
vm_name      = "ubuntu-simple-01"
template_name = "ubuntu-22.04-template"
```

### Customized Deployment

For a deployment with static IP and custom hostname:

```hcl
# terraform.tfvars
customize_vm = true
vm_name      = "ubuntu-custom-01"
template_name = "ubuntu-22.04-template"

# Network customization
hostname      = "web-server-01"
domain        = "company.com"
ipv4_address  = "192.168.1.100"
ipv4_netmask  = 24
ipv4_gateway  = "192.168.1.1"
dns_servers   = ["8.8.8.8", "1.1.1.1"]
```

### Resource Configuration

Customize VM resources:

```hcl
# terraform.tfvars
num_cpus  = 4
memory    = 8192  # 8GB
disk_size = 100   # 100GB
```

## Variables Reference

### Required Variables

| Variable | Description | Type |
|----------|-------------|------|
| `vsphere_user` | vSphere username | `string` |
| `vsphere_password` | vSphere password | `string` |
| `vsphere_server` | vSphere server hostname/IP | `string` |
| `datacenter` | vSphere datacenter name | `string` |
| `datastore` | vSphere datastore name | `string` |
| `cluster` | vSphere cluster name | `string` |
| `network` | vSphere network name | `string` |
| `vm_folder` | vSphere folder path | `string` |
| `template_name` | Ubuntu template name | `string` |
| `vm_name` | Name for the new VM | `string` |

### Optional Variables

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `num_cpus` | Number of CPUs | `number` | `2` |
| `memory` | Memory in MB | `number` | `4096` |
| `disk_size` | Disk size in GB | `number` | `null` (uses template size) |
| `customize_vm` | Enable VM customization | `bool` | `false` |
| `hostname` | VM hostname | `string` | `""` |
| `domain` | VM domain | `string` | `""` |
| `ipv4_address` | Static IP address | `string` | `""` |
| `ipv4_netmask` | IP netmask | `number` | `24` |
| `ipv4_gateway` | IP gateway | `string` | `""` |
| `dns_servers` | DNS servers | `list(string)` | `["8.8.8.8", "8.8.4.4"]` |
| `wait_for_guest_ip_timeout` | Guest IP timeout (minutes) | `number` | `5` |
| `wait_for_guest_net_timeout` | Guest network timeout (minutes) | `number` | `5` |

## Outputs

The module provides comprehensive outputs about the deployed VM:

| Output | Description |
|--------|-------------|
| `vm_id` | The ID of the deployed VM |
| `vm_name` | The name of the deployed VM |
| `vm_guest_id` | The guest ID of the deployed VM |
| `vm_moid` | The managed object ID |
| `vm_uuid` | The UUID of the VM |
| `vm_guest_ip_addresses` | All guest IP addresses |
| `vm_default_ip_address` | The default IP address |
| `vm_power_state` | The power state |
| `vm_resource_pool_id` | The resource pool ID |
| `vm_datastore_id` | The datastore ID |
| `vm_folder` | The folder path |

## Template Requirements

Your Ubuntu template should meet these requirements:

- **Guest OS**: Ubuntu (any recent version)
- **VMware Tools**: Installed and up to date
- **Network**: Configured for DHCP or ready for static IP
- **Template Status**: Converted to template in vSphere
- **Disk**: Properly sized and configured

### Creating a Template

1. **Deploy Ubuntu VM** from ISO or OVA
2. **Install VMware Tools**:
   ```bash
   sudo apt update
   sudo apt install open-vm-tools
   ```
3. **Generalize the VM** (optional):
   ```bash
   sudo cloud-init clean
   sudo rm -f /etc/machine-id
   ```
4. **Convert to Template** in vSphere

## Security Considerations

### Credential Management
- **Never commit passwords** to version control
- Use environment variables for sensitive data:
  ```bash
  export TF_VAR_vsphere_password="your-password"
  ```
- Consider using Terraform Cloud or other secure variable storage

### Network Security
- **Use secure networks** for management traffic
- **Implement proper firewalls** and access controls
- **Consider VLANs** for network segmentation
- **Enable SSL verification** in production

### VM Security
- **Regular updates**: Keep Ubuntu templates updated
- **Security patches**: Apply security updates regularly
- **Access controls**: Implement proper user permissions
- **Monitoring**: Set up monitoring and alerting

## Troubleshooting

### Common Issues

#### Template Not Found
```
Error: template not found
```
**Solution**: Verify the template name and ensure it exists in the specified datacenter

#### Network Configuration Issues
```
Error: network customization failed
```
**Solution**: 
- Verify network settings (IP, gateway, DNS)
- Ensure network is accessible from the cluster
- Check for IP conflicts

#### Timeout Issues
```
Error: timeout waiting for guest IP
```
**Solution**:
- Increase timeout values
- Check network connectivity
- Verify VMware Tools is running

#### Permission Issues
```
Error: insufficient privileges
```
**Solution**:
- Verify vSphere user permissions
- Ensure user has VM creation rights
- Check folder and resource pool permissions

### Debugging Commands

```bash
# Validate configuration
terraform validate

# Check syntax
terraform fmt -check

# Show current state
terraform show

# List resources
terraform state list

# Refresh state
terraform refresh
```

## Examples

### Web Server Deployment

```hcl
# terraform.tfvars
vm_name       = "web-server-01"
template_name = "ubuntu-22.04-template"
customize_vm  = true
hostname      = "web-server-01"
domain        = "company.com"
ipv4_address  = "192.168.1.100"
ipv4_gateway  = "192.168.1.1"
num_cpus      = 2
memory        = 4096
```

### Database Server Deployment

```hcl
# terraform.tfvars
vm_name       = "db-server-01"
template_name = "ubuntu-22.04-template"
customize_vm  = true
hostname      = "db-server-01"
domain        = "company.com"
ipv4_address  = "192.168.1.101"
ipv4_gateway  = "192.168.1.1"
num_cpus      = 4
memory        = 8192
disk_size     = 100
```

## Integration

### Ansible Integration
Use this Terraform configuration with Ansible for post-deployment configuration:

```bash
# Get VM IP for Ansible
VM_IP=$(terraform output -raw vm_default_ip_address)

# Run Ansible playbook
ansible-playbook -i "$VM_IP," playbook.yml
```

### CI/CD Integration
Integrate with your CI/CD pipeline for automated deployments:

```yaml
# Example GitHub Actions step
- name: Deploy Ubuntu VM
  run: |
    cd terraform/VM/Deploy-Ubuntu
    terraform init
    terraform apply -auto-approve
```

## Contributing

When contributing to this module:

1. **Follow naming conventions** for variables and resources
2. **Add validation** for critical variables
3. **Update documentation** for new features
4. **Test thoroughly** in your environment
5. **Follow security best practices**

## Support

For issues and questions:

- **Terraform Documentation**: [terraform.io/docs](https://terraform.io/docs)
- **vSphere Provider**: [registry.terraform.io/providers/vmware/vsphere](https://registry.terraform.io/providers/vmware/vsphere)
- **VMware Documentation**: [docs.vmware.com](https://docs.vmware.com)
- **Project Issues**: Use the main project repository 