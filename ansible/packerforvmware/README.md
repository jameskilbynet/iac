# Packer for VMware vSphere - Requirements Installation

Automated installation of Packer, Terraform, Ansible, and supporting tools for VMware vSphere template automation.

## Overview

This playbook installs all necessary tools and dependencies for building VMware vSphere VM templates using HashiCorp Packer. It's designed to prepare a build server or workstation for infrastructure-as-code operations with VMware environments.

## Features

- ✅ Installs HashiCorp Packer from official repository
- ✅ Installs HashiCorp Terraform
- ✅ Installs Ansible from official PPA
- ✅ Installs gomplate for template rendering
- ✅ Installs required system utilities (git, jq, xorriso, etc.)
- ✅ Configures GPG keys and repositories securely
- ✅ Initializes Packer plugins
- ✅ Version-pinned gomplate for stability

## Prerequisites

### Control Machine (Local)
- Ansible 2.9+
- SSH access to target host(s)

### Target Host
- Ubuntu/Debian operating system
- SSH access with sudo privileges
- Internet access for downloading packages
- Minimum 4GB disk space

## Quick Start

### 1. Create Inventory File

Create `inventory.ini`:

```ini
[packer_builders]
buildserver.example.com ansible_user=your_username
```

### 2. Run the Playbook

```bash
ansible-playbook -i inventory.ini install_packer_requirements.yml
```

### 3. Verify Installation

```bash
ansible packer_builders -i inventory.ini -m shell -a "packer version"
ansible packer_builders -i inventory.ini -m shell -a "terraform version"
ansible packer_builders -i inventory.ini -m shell -a "ansible --version"
ansible packer_builders -i inventory.ini -m shell -a "gomplate --version"
```

## What the Playbook Does

1. **Updates Package Cache**: Ensures latest package information
2. **Installs Prerequisites**: Software properties, wget, gnupg, curl, lsb-release
3. **Adds HashiCorp Repository**: Configures official HashiCorp APT repository with GPG key
4. **Adds Ansible PPA**: Configures Ansible PPA for latest Ansible version
5. **Installs Packer**: HashiCorp Packer for building VM images
6. **Installs Terraform**: Infrastructure provisioning tool
7. **Installs Ansible**: Configuration management and automation
8. **Installs Utilities**: 
   - `git` - Version control
   - `jq` - JSON processor
   - `xorriso` - ISO manipulation
   - `whois` - Network utilities (includes mkpasswd)
   - `unzip` - Archive extraction
9. **Installs gomplate**: Template rendering tool
10. **Initializes Packer**: Sets up Packer plugin directory

## Installed Tools

### Core Tools

| Tool | Purpose | Repository |
|------|---------|------------|
| **Packer** | VM template building | HashiCorp official |
| **Terraform** | Infrastructure provisioning | HashiCorp official |
| **Ansible** | Configuration automation | Ansible PPA |
| **gomplate** | Template rendering | GitHub releases |

### Utilities

| Tool | Purpose |
|------|---------|
| **git** | Version control for infrastructure code |
| **jq** | JSON parsing for Packer/Terraform outputs |
| **xorriso** | ISO creation and manipulation for custom ISOs |
| **whois** | Provides `mkpasswd` for password hashing |
| **unzip** | Extract downloaded archives |
| **python3/pip** | Python scripting support |

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `gomplate_version` | `4.3.0` | Version of gomplate to install |
| `gomplate_arch` | `linux-amd64` | Architecture for gomplate binary |

## Use Cases

This setup is ideal for:

1. **Packer Template Building**: Creating VMware vSphere VM templates
2. **Infrastructure Automation**: Using Terraform to provision VMs from templates
3. **Configuration Management**: Using Ansible to configure deployed VMs
4. **CI/CD Pipelines**: Automated template building and deployment
5. **Template Customization**: Using gomplate for dynamic template generation

## Integration with Packer Examples

This playbook prepares the environment for projects like:
- [packer-examples-for-vsphere](https://github.com/vmware-samples/packer-examples-for-vsphere)
- Custom Packer templates for VMware

### Example Workflow

1. **Install Requirements** (this playbook)
2. **Clone Packer Repository**:
   ```bash
   git clone https://github.com/vmware-samples/packer-examples-for-vsphere.git
   ```
3. **Configure Variables**: Set vCenter credentials, network settings, etc.
4. **Build Templates**: Run Packer builds
5. **Deploy with Terraform**: Provision VMs from templates
6. **Configure with Ansible**: Apply configurations to deployed VMs

## Post-Installation

### Verify Installations

```bash
# Check all tool versions
packer version
terraform version
ansible --version
gomplate --version
git --version
jq --version
```

### Initialize Packer Plugins

For specific Packer templates, initialize required plugins:

```bash
cd /path/to/packer/template
packer init .
```

### Configure vCenter Credentials

Set up environment variables for VMware vCenter:

```bash
export VCENTER_SERVER="vcenter.example.com"
export VCENTER_USERNAME="administrator@vsphere.local"
export VCENTER_PASSWORD="your_password"
```

### Test Packer

Validate a Packer template:

```bash
packer validate template.pkr.hcl
```

Build a template:

```bash
packer build template.pkr.hcl
```

## Advanced Usage

### Custom gomplate Version

```bash
ansible-playbook -i inventory.ini install_packer_requirements.yml \
  -e "gomplate_version=4.4.0"
```

### Different Architecture

```bash
ansible-playbook -i inventory.ini install_packer_requirements.yml \
  -e "gomplate_arch=linux-arm64"
```

### Check Mode (Dry Run)

```bash
ansible-playbook -i inventory.ini install_packer_requirements.yml --check
```

### Verbose Output

```bash
ansible-playbook -i inventory.ini install_packer_requirements.yml -vvv
```

## Troubleshooting

### HashiCorp Repository Issues

```
Failed to fetch from HashiCorp repository
```

**Solution**: Verify GPG key and repository configuration:

```bash
# Manually add repository
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
```

### Packer Plugin Initialization Failed

```
Error initializing Packer plugins
```

**Solution**: This is expected on first run. Initialize plugins manually in your Packer project directory:

```bash
cd /path/to/packer/project
packer init .
```

### gomplate Not Found

```
gomplate: command not found
```

**Solution**: Verify installation and PATH:

```bash
ls -la /usr/local/bin/gomplate
echo $PATH
```

If missing, re-run the playbook.

### Ansible PPA Issues

```
Failed to add Ansible PPA
```

**Solution**: The PPA might be temporarily unavailable or your Ubuntu version may not be supported. Check [Ansible documentation](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) for alternatives.

## Security Considerations

- **GPG Keys**: The playbook verifies GPG keys for all repositories
- **Official Sources**: Only uses official HashiCorp and Ansible repositories
- **Version Pinning**: gomplate version is pinned for reproducibility
- **Credential Management**: Never store vCenter credentials in playbooks
- **Build Isolation**: Consider using dedicated build servers
- **Access Control**: Limit who can access the build server

## Integration with Infrastructure

This playbook is part of a larger automation workflow:

1. **Build Server Setup** (this playbook)
2. **Template Building** (Packer)
3. **Infrastructure Deployment** (Terraform)
4. **Configuration Management** (Other Ansible playbooks)
5. **Container Deployment** (Docker/Portainer)

## CI/CD Integration

### GitLab CI Example

```yaml
build-template:
  stage: build
  script:
    - packer validate ubuntu.pkr.hcl
    - packer build ubuntu.pkr.hcl
  only:
    - main
```

### GitHub Actions Example

```yaml
name: Build VM Template
on:
  push:
    branches: [main]
jobs:
  build:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v2
      - name: Build with Packer
        run: packer build ubuntu.pkr.hcl
```

## Maintenance

### Update Tools

Re-run the playbook to update to latest versions:

```bash
ansible-playbook -i inventory.ini install_packer_requirements.yml
```

### Update Specific Tool

```bash
# Update only Packer
sudo apt-get update && sudo apt-get install --only-upgrade packer

# Update only Terraform
sudo apt-get install --only-upgrade terraform
```

### Uninstall

```bash
sudo apt-get remove packer terraform ansible
sudo rm /usr/local/bin/gomplate
```

## Additional Resources

- [Packer Documentation](https://www.packer.io/docs)
- [Packer VMware Builder](https://www.packer.io/plugins/builders/vmware)
- [Terraform VMware Provider](https://registry.terraform.io/providers/hashicorp/vsphere/latest/docs)
- [gomplate Documentation](https://docs.gomplate.ca/)
- [Packer Examples for vSphere](https://github.com/vmware-samples/packer-examples-for-vsphere)
- [VMware vSphere Documentation](https://docs.vmware.com/)
- [Main Project README](../README.md)

## Contributing

When modifying this playbook:

1. Test on clean Ubuntu/Debian system
2. Verify all tools install correctly
3. Test with actual Packer builds
4. Update tool versions as needed
5. Update this README with changes

## Support

For issues related to:
- **Packer**: Check [Packer documentation](https://www.packer.io/docs)
- **Terraform**: Check [Terraform documentation](https://www.terraform.io/docs)
- **Ansible**: Check [Ansible documentation](https://docs.ansible.com/)
- **VMware**: Check [VMware documentation](https://docs.vmware.com/)
- **This Playbook**: See the [main project README](../README.md)
