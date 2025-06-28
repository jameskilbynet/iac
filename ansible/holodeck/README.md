# Holodeck Ansible Playbooks

This directory contains Ansible playbooks for managing VMware vSphere infrastructure components, specifically focused on virtual switch and network configuration for the Holodeck environment.

## Overview

The Holodeck environment appears to be a test/development environment for VMware infrastructure automation, as evidenced by the folder structure in the broader project (`Test/HoloDeck`). These playbooks provide automated configuration for VMware networking components.

## Playbooks

### vSwitch.yml

**Purpose**: Creates a virtual switch and port group on a VMware ESXi host with specific configuration for high-performance networking.

**Features**:
- Creates a vSwitch with no uplinks (for internal networking)
- Configures MTU size of 9000 bytes (Jumbo frames)
- Creates a port group with promiscuous mode and MAC address changes enabled
- Designed for VLC (Video LAN Client) networking requirements

**Configuration**:
- **vSwitch Name**: `VLC-A`
- **Port Group Name**: `VLC-A-PG`
- **MTU Size**: 9000 bytes
- **VLAN ID**: 0 (no VLAN tagging)
- **Security Settings**: Promiscuous mode, forged transmits, and MAC changes enabled

## Prerequisites

1. **Ansible Collections**: The `community.vmware` collection must be installed
   ```bash
   ansible-galaxy collection install community.vmware
   ```

2. **VMware vSphere Environment**: Access to an ESXi host or vCenter server

3. **Network Connectivity**: Ability to reach the target VMware host

## Usage

### Before Running

1. **Update Variables**: Edit the variables in `vSwitch.yml`:
   ```yaml
   vars:
     hostname: "your-esxi-host.local"  # Replace with your ESXi host
     username: "root"                  # ESXi username
     password: "your_esxi_password"    # ESXi password
     validate_certs: false             # Set to true for production
   ```

2. **Verify Collection**: Ensure the VMware collection is available:
   ```bash
   ansible-galaxy collection list | grep vmware
   ```

### Running the Playbook

```bash
# Run the playbook
ansible-playbook vSwitch.yml

# Run with verbose output for debugging
ansible-playbook vSwitch.yml -v

# Run with custom variables
ansible-playbook vSwitch.yml --extra-vars "hostname=esxi01.company.com"
```

## Security Considerations

⚠️ **Important Security Notes**:

1. **Certificate Validation**: The playbook defaults to `validate_certs: false`. In production environments, set this to `true` and ensure proper SSL certificates are configured.

2. **Credentials**: Never commit passwords to version control. Consider using:
   - Ansible Vault for encrypted variables
   - Environment variables
   - External secret management systems

3. **Network Security**: The created port group has relaxed security settings (promiscuous mode, MAC changes). Ensure this aligns with your security requirements.

## Troubleshooting

### Common Issues

1. **Module Not Found Error**:
   ```
   couldn't resolve module/action 'community.vmware.vmware_host_vss'
   ```
   **Solution**: Install the VMware collection:
   ```bash
   ansible-galaxy collection install community.vmware
   ```

2. **Authentication Failures**:
   - Verify ESXi host credentials
   - Check network connectivity
   - Ensure user has appropriate permissions

3. **vSwitch Creation Fails**:
   - Verify the vSwitch name doesn't already exist
   - Check available resources on the ESXi host
   - Ensure proper permissions for vSwitch creation

### Debugging

Enable verbose output to troubleshoot issues:
```bash
ansible-playbook vSwitch.yml -vvv
```

## Integration with Broader Infrastructure

This playbook is part of a larger infrastructure automation project that includes:

- **Terraform**: VM deployment and infrastructure provisioning
- **Packer**: VM template creation
- **Other Ansible Playbooks**: Docker, Vault, vGPU, and system updates
- **VMware Tools**: Various VMware-specific configurations

The Holodeck environment serves as a test bed for these automation tools before deployment to production environments.

## Related Resources

- [VMware vSphere Documentation](https://docs.vmware.com/en/VMware-vSphere/)
- [Ansible VMware Collection Documentation](https://docs.ansible.com/ansible/latest/collections/community/vmware/)
- [Project Root README](../README.md)

## Contributing

When adding new playbooks to this directory:

1. Follow the existing naming conventions
2. Include comprehensive variable documentation
3. Add security considerations
4. Test in the Holodeck environment before production use
5. Update this README with new playbook information

## Support

For issues related to:
- **Ansible Playbooks**: Check the troubleshooting section above
- **VMware Configuration**: Consult VMware documentation
- **Project Structure**: Refer to the main project README 