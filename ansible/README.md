# Ansible Playbooks

This directory contains a comprehensive collection of Ansible playbooks for infrastructure automation, covering various aspects of system administration, containerization, virtualization, and security.

## Overview

These playbooks are designed to automate common infrastructure tasks across different environments, from development to production. They follow best practices for security, reliability, and maintainability.

## Directory Structure

```
ansible/
├── docker/          # Docker installation and configuration
├── holodeck/        # VMware vSphere networking (test environment)
├── portainer/       # Portainer container management
├── traefik/         # Traefik reverse proxy and Cloudflare integration
├── updates/         # System updates and maintenance
├── vault/           # HashiCorp Vault secrets management
└── vGPU/            # NVIDIA GPU drivers and container toolkit
```

## Playbooks by Category

### 🐳 Container Management

#### Docker Installation (`docker/install_docker.yml`)
**Purpose**: Installs Docker Engine on Ubuntu systems with proper repository configuration.

**Features**:
- Installs Docker CE from official repository
- Configures GPG keys and APT sources
- Includes Docker Compose and Buildx plugins
- Handles system reboots if required
- Enables and starts Docker service

**Usage**:
```bash
ansible-playbook docker/install_docker.yml
```

#### Portainer Agent (`portainer/install_portainer_agent.yml`)
**Purpose**: Deploys Portainer agent for container management and monitoring.

**Features**:
- Deploys Portainer agent as a Docker container
- Exposes port 9001 for management interface
- Mounts Docker socket and volumes for full access
- Uses pinned version for stability

**Usage**:
```bash
ansible-playbook portainer/install_portainer_agent.yml
```

### ☁️ Cloudflare & Traefik Integration

#### Cloudflare Token Validation (`traefik/validate_cloudflare_token.yml`)
**Purpose**: Validates Cloudflare API tokens and verifies domain access for Traefik integration.

**Features**:
- Interactive token validation
- Domain access verification
- DNS permissions testing
- Comprehensive validation report
- Supports both file-based and interactive token input

**Usage**:
```bash
ansible-playbook traefik/validate_cloudflare_token.yml
```

### 🔐 Security & Secrets Management

#### HashiCorp Vault Installation (`vault/install_vault.yml`)
**Purpose**: Installs and configures HashiCorp Vault for secrets management.

**Features**:
- Installs Vault from official HashiCorp repository
- Creates dedicated vault user and group
- Configures file-based storage backend
- Sets up systemd service
- Enables web UI (TLS disabled for development)

**Configuration**:
- **Version**: 1.15.5
- **Port**: 8200
- **Storage**: File-based (`/opt/vault/data`)
- **UI**: Enabled

**Usage**:
```bash
ansible-playbook vault/install_vault.yml
```

### 🖥️ System Maintenance

#### Ubuntu System Updates (`updates/patch_ubuntu.yml`)
**Purpose**: Performs comprehensive system updates on Ubuntu/Debian systems.

**Features**:
- Updates package cache and all packages
- Handles kernel updates with automatic reboot
- Removes unused dependencies
- Configurable reboot behavior

**Usage**:
```bash
ansible-playbook updates/patch_ubuntu.yml
```

### 🎮 GPU & Virtualization

#### NVIDIA vGPU Drivers (`vGPU/install_nvidia_drivers.yml`)
**Purpose**: Installs NVIDIA vGPU drivers for GPU virtualization.

**Features**:
- Installs NVIDIA vGPU drivers from NFS share
- Handles build dependencies and kernel headers
- Supports silent installation
- Checks for existing installations
- Configures NFS mounting for driver distribution

**Prerequisites**:
- NFS server with NVIDIA drivers
- Build tools and kernel headers
- Network connectivity to NFS share

**Usage**:
```bash
ansible-playbook vGPU/install_nvidia_drivers.yml
```

#### NVIDIA Container Toolkit (`vGPU/install_nvidia_containertoolkit.yml`)
**Purpose**: Installs NVIDIA Container Toolkit for Docker GPU support.

**Features**:
- Installs NVIDIA Container Toolkit
- Configures Docker runtime for GPU access
- Starts NVIDIA vGPU licensing daemon
- Tests GPU access with nvidia-smi

**Usage**:
```bash
ansible-playbook vGPU/install_nvidia_containertoolkit.yml
```

#### NVIDIA Container Test (`vGPU/test_nvidia_container.yml`)
**Purpose**: Tests NVIDIA Container Toolkit functionality.

**Features**:
- Runs nvidia-smi inside Docker container
- Verifies GPU access and driver functionality
- Provides diagnostic output

**Usage**:
```bash
ansible-playbook vGPU/test_nvidia_container.yml
```

### 🏗️ VMware Infrastructure

#### vSwitch Configuration (`holodeck/vSwitch.yml`)
**Purpose**: Creates VMware vSwitches and port groups for high-performance networking.

**Features**:
- Creates vSwitch with no uplinks (internal networking)
- Configures Jumbo frames (MTU 9000)
- Sets up port groups with relaxed security
- Designed for VLC networking requirements

**Prerequisites**:
- VMware Ansible collection: `community.vmware`
- ESXi host access

**Usage**:
```bash
ansible-playbook holodeck/vSwitch.yml
```

## Prerequisites

### Required Collections
Install the required Ansible collections:
```bash
ansible-galaxy collection install community.vmware
ansible-galaxy collection install community.docker
```

### System Requirements
- **OS**: Ubuntu/Debian (primary target)
- **Ansible**: 2.9+
- **Python**: 3.6+
- **Network**: Internet access for package downloads

### VMware Requirements
- ESXi host or vCenter server access
- Appropriate permissions for vSwitch creation
- Network connectivity to VMware environment

### GPU Requirements
- NVIDIA GPU hardware
- NFS server with NVIDIA drivers
- Kernel headers matching running kernel

## Security Considerations

### 🔒 Credential Management
- **Never commit passwords** to version control
- Use Ansible Vault for sensitive variables
- Consider environment variables for secrets
- Implement proper access controls

### 🌐 Network Security
- **Certificate validation**: Enable in production
- **Firewall rules**: Configure appropriate access
- **VPN access**: Use for remote deployments
- **Network segmentation**: Isolate management traffic

### 🛡️ System Security
- **Regular updates**: Use the updates playbook
- **Access controls**: Implement proper user permissions
- **Audit logging**: Monitor system changes
- **Backup strategies**: Protect critical data

## Best Practices

### Playbook Execution
1. **Test in development** before production
2. **Use inventory files** for host management
3. **Implement idempotency** for safe re-runs
4. **Monitor execution** with verbose output

### Variable Management
1. **Use group_vars** for environment-specific settings
2. **Implement variable precedence** correctly
3. **Document all variables** with descriptions
4. **Validate input** with assertions

### Error Handling
1. **Implement proper error handling**
2. **Use conditional tasks** where appropriate
3. **Provide meaningful error messages**
4. **Log all operations** for troubleshooting

## Troubleshooting

### Common Issues

#### Collection Not Found
```
couldn't resolve module/action 'community.vmware.vmware_host_vss'
```
**Solution**: Install required collections
```bash
ansible-galaxy collection install community.vmware
```

#### Authentication Failures
- Verify credentials and permissions
- Check network connectivity
- Ensure proper SSL certificate handling

#### Package Installation Issues
- Update package cache: `apt update`
- Check disk space availability
- Verify repository configuration

#### GPU Driver Issues
- Verify kernel headers match running kernel
- Check NFS connectivity and permissions
- Ensure GPU hardware is properly detected

### Debugging Commands
```bash
# Verbose output
ansible-playbook playbook.yml -v

# Extra verbose
ansible-playbook playbook.yml -vvv

# Check syntax
ansible-playbook playbook.yml --syntax-check

# Dry run
ansible-playbook playbook.yml --check
```

## Integration with Broader Infrastructure

These playbooks are part of a larger infrastructure automation project that includes:

- **Terraform**: Infrastructure provisioning
- **Packer**: VM template creation
- **VMware Tools**: vSphere automation
- **Container Orchestration**: Docker and Kubernetes

### Workflow Integration
1. **Provision infrastructure** with Terraform
2. **Create VM templates** with Packer
3. **Deploy applications** with Ansible
4. **Monitor and maintain** with integrated tools

## Contributing

When adding new playbooks:

1. **Follow naming conventions** (lowercase with underscores)
2. **Include comprehensive documentation**
3. **Implement proper error handling**
4. **Add security considerations**
5. **Test thoroughly** before committing
6. **Update this README** with new playbook information

## Support

For issues and questions:

- **Ansible Documentation**: [docs.ansible.com](https://docs.ansible.com/)
- **Collection Documentation**: Check individual collection docs
- **VMware Documentation**: [docs.vmware.com](https://docs.vmware.com/)
- **Project Issues**: Use the main project repository

## License

This project follows the same license as the parent repository. Please refer to the main project documentation for licensing information. 