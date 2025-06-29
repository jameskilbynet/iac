# Infrastructure as Code (IAC)

A comprehensive Infrastructure as Code repository for automating VMware vSphere environments, container management, and system administration tasks. This project is designed to work with [Semaphore](https://semaphoreui.com/) for automated deployments and management.

## 🏗️ Project Overview

This repository contains a complete set of automation tools for managing modern infrastructure:

- **Terraform**: Infrastructure provisioning and VM deployment
- **Ansible**: Configuration management and system automation
- **Packer**: VM template creation and standardization
- **PowerShell**: VMware administration and power management
- **Miscellaneous Tools**: Utilities and shortcuts for infrastructure management

## 📁 Directory Structure

```
iac/
├── ansible/                    # Configuration management and automation
│   ├── docker/                 # Docker installation and configuration
│   ├── holodeck/               # VMware vSphere networking (test environment)
│   ├── portainer/              # Portainer container management
│   ├── traefik/                # Traefik reverse proxy and Cloudflare integration
│   ├── updates/                # System updates and maintenance
│   ├── vault/                  # HashiCorp Vault secrets management
│   └── vGPU/                   # NVIDIA GPU drivers and container toolkit
├── terraform/                  # Infrastructure as Code
│   ├── Infra/                  # vSphere infrastructure components
│   │   ├── vSphereContentLibrary/  # Content library management
│   │   ├── vSphereFolders/         # VM folder organization
│   │   ├── vSphereRoles/           # vSphere role definitions
│   │   └── vSphereVCSetup/         # vCenter and cluster setup
│   └── VM/                     # Virtual machine deployments
│       ├── Deploy-FAH/         # Folding@Home appliance deployment
│       ├── Deploy-HoloConsole/ # HoloConsole VM deployment
│       ├── Deploy-Ubuntu/      # Ubuntu VM deployment from templates
│       └── VMCLogs/            # Photon VM for logging
├── packer/                     # VM template creation
│   └── manual/                 # Manual template builds
│       ├── http/               # HTTP files for automated installation
│       ├── ubuntu-vsphere.pkr.hcl  # Ubuntu 24.04 template configuration
│       └── variables.pkrvars.hcl.example  # Template variables
├── powershell/                 # PowerShell automation scripts
│   └── VMware/                 # VMware-specific PowerShell scripts
│       ├── SetPowerBalanced.ps1    # Set ESXi power policy to balanced
│       └── SetPowerLow.ps1         # Set ESXi power policy to low power
├── misc/                       # Miscellaneous utilities
│   └── shortcuts.ps1           # VMware bookmark generator
├── docker/                     # Docker-related configurations (placeholder)
├── bash/                       # Bash scripts (placeholder)
└── README.md                   # This file
```

## 🚀 Quick Start

### Prerequisites

- **Terraform**: >= 1.0.0
- **Ansible**: >= 2.9
- **Packer**: >= 1.8.0
- **PowerShell**: >= 5.1 (for Windows automation)
- **vSphere Environment**: ESXi/vCenter access
- **Semaphore**: For automated deployments

### Initial Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd iac
   ```

2. **Configure vSphere credentials**:
   ```bash
   export TF_VAR_vsphere_user="your-username"
   export TF_VAR_vsphere_password="your-password"
   export TF_VAR_vsphere_server="vcenter.example.com"
   ```

3. **Deploy infrastructure**:
   ```bash
   # Deploy vSphere infrastructure
   cd terraform/Infra/vSphereFolders
   terraform init && terraform apply
   
   cd ../vSphereContentLibrary
   terraform init && terraform apply
   ```

4. **Create VM templates**:
   ```bash
   cd packer/manual
   packer init ubuntu-vsphere.pkr.hcl
   packer build -var-file="variables.pkrvars.hcl" ubuntu-vsphere.pkr.hcl
   ```

## 🛠️ Components

### Terraform Infrastructure

#### Infrastructure Components (`terraform/Infra/`)

- **vSphere Folders**: Organized VM management structure
- **vSphere Content Library**: Template and OVA distribution
- **vSphere Roles**: Security and access control
- **vSphere vCenter Setup**: Datacenter and cluster configuration

#### VM Deployments (`terraform/VM/`)

- **Deploy-Ubuntu**: Ubuntu VM deployment from templates
- **Deploy-FAH**: Folding@Home distributed computing appliance
- **Deploy-HoloConsole**: Virtual reality management VM
- **VMCLogs**: Photon OS logging and monitoring VM

### Ansible Automation

#### System Management (`ansible/`)

- **Docker**: Container engine installation and configuration
- **Portainer**: Container management platform deployment
- **Vault**: HashiCorp Vault secrets management
- **Updates**: System updates and maintenance automation

#### Specialized Automation

- **vGPU**: NVIDIA GPU drivers and container toolkit
- **Traefik**: Reverse proxy and Cloudflare integration
- **Holodeck**: VMware vSphere networking for test environments

### Packer Templates

#### VM Template Creation (`packer/`)

- **Ubuntu 24.04**: Automated Ubuntu server template creation
- **vSphere Integration**: Native vSphere template deployment
- **Automated Installation**: Unattended OS installation

### PowerShell Automation

#### VMware Management (`powershell/VMware/`)

- **Power Management**: ESXi host power policy configuration
- **Bookmark Generation**: Automated VMware management interface bookmarks

## 🔄 Workflow Integration

### Typical Deployment Workflow

1. **Infrastructure Setup**:
   ```bash
   # Deploy vSphere infrastructure
   terraform -chdir=terraform/Infra/vSphereFolders apply
   terraform -chdir=terraform/Infra/vSphereContentLibrary apply
   ```

2. **Template Creation**:
   ```bash
   # Create Ubuntu template
   packer build -var-file="packer/manual/variables.pkrvars.hcl" packer/manual/ubuntu-vsphere.pkr.hcl
   ```

3. **VM Deployment**:
   ```bash
   # Deploy Ubuntu VM
   terraform -chdir=terraform/VM/Deploy-Ubuntu apply
   ```

4. **Configuration Management**:
   ```bash
   # Configure deployed VM
   ansible-playbook ansible/docker/install_docker.yml
   ansible-playbook ansible/portainer/install_portainer_agent.yml
   ```

### Semaphore Integration

This project is designed to work with Semaphore for automated deployments:

- **CI/CD Pipeline**: Automated testing and deployment
- **Environment Management**: Multi-environment support
- **Secret Management**: Secure credential handling
- **Monitoring**: Deployment status and health checks

## 🔐 Security Considerations

### Credential Management

- **Never commit secrets** to version control
- **Use environment variables** for sensitive data
- **Implement proper access controls** for all tools
- **Regular credential rotation** and audit

### Network Security

- **Secure management networks** for infrastructure access
- **VPN connectivity** for remote management
- **Firewall rules** for service access
- **SSL/TLS encryption** for all communications

### Infrastructure Security

- **Role-based access control** (RBAC) implementation
- **Resource isolation** through folders and resource pools
- **Regular security updates** and patch management
- **Audit logging** and monitoring

## 📊 Monitoring and Maintenance

### Health Checks

- **Infrastructure monitoring** with vRealize Operations
- **Application monitoring** with custom dashboards
- **Log aggregation** with centralized logging
- **Alert management** for critical issues

### Maintenance Procedures

- **Regular backups** of Terraform state and configurations
- **Template updates** for security patches
- **Infrastructure audits** and compliance checks
- **Performance optimization** and capacity planning

## 🐛 Troubleshooting

### Common Issues

#### Terraform Issues
```bash
# Validate configuration
terraform validate

# Check state
terraform state list

# Refresh state
terraform refresh
```

#### Ansible Issues
```bash
# Test connectivity
ansible all -m ping

# Verbose output
ansible-playbook playbook.yml -vvv

# Check syntax
ansible-playbook --syntax-check playbook.yml
```

#### Packer Issues
```bash
# Validate configuration
packer validate template.pkr.hcl

# Debug build
packer build -debug template.pkr.hcl
```

### Debugging Commands

```bash
# Check vSphere connectivity
govc about

# Verify Ansible collections
ansible-galaxy collection list

# Test Terraform providers
terraform providers
```

## 🤝 Contributing

### Development Guidelines

1. **Follow naming conventions** for all resources
2. **Implement proper error handling** in all scripts
3. **Add comprehensive documentation** for new features
4. **Test thoroughly** in development environment
5. **Follow security best practices**

### Code Standards

- **Terraform**: Use consistent formatting and variable naming
- **Ansible**: Follow playbook structure and naming conventions
- **PowerShell**: Use proper error handling and logging
- **Documentation**: Keep README files updated

## 📚 Documentation

### Component Documentation

- **[Ansible README](ansible/README.md)**: Complete Ansible playbook documentation
- **[Terraform README](terraform/README.md)**: Infrastructure automation guide
- **[Packer README](packer/manual/README.md)**: Template creation documentation

### External Resources

- **[Terraform Documentation](https://terraform.io/docs)**
- **[Ansible Documentation](https://docs.ansible.com/)**
- **[Packer Documentation](https://packer.io/docs)**
- **[VMware vSphere Documentation](https://docs.vmware.com/en/VMware-vSphere/)**
- **[Semaphore Documentation](https://semaphoreui.com/docs)**

## 📞 Support

### Getting Help

- **Project Issues**: Use GitHub issues for bug reports
- **Documentation**: Check component-specific README files
- **Community**: Engage with the infrastructure automation community
- **Professional Support**: Contact for enterprise support

### Maintenance

This project is actively maintained and updated regularly. For the latest updates and security patches, ensure you're using the latest version of all tools and dependencies.

## 📄 License

This project follows the same license as the parent repository. Please refer to the main project documentation for licensing information.

---

**Note**: This infrastructure automation project is designed for production use but should be thoroughly tested in your specific environment before deployment. 