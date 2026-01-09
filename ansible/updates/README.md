# Ubuntu System Updates with Ansible

Automated system patching and updates for Ubuntu/Debian systems with automatic reboot handling.

## Overview

This playbook performs comprehensive system updates on Ubuntu and Debian systems, including kernel updates with automatic reboot management when required.

## Features

- ✅ Updates APT package cache
- ✅ Upgrades all installed packages to latest versions
- ✅ Detects when system reboot is required (kernel updates)
- ✅ Automatically reboots system when needed
- ✅ Waits for system to come back online
- ✅ Removes unused package dependencies (autoremove)
- ✅ Idempotent and safe to run regularly

## Prerequisites

### Control Machine (Local)
- Ansible 2.9+
- SSH access to target host(s)

### Target Host
- Ubuntu/Debian operating system
- SSH access with sudo privileges
- Internet access for downloading updates

## Quick Start

### 1. Create Inventory File

Create `inventory.ini`:

```ini
[servers]
server1.example.com ansible_user=your_username
server2.example.com ansible_user=your_username

[web_servers]
web1.example.com ansible_user=your_username
web2.example.com ansible_user=your_username

[database_servers]
db1.example.com ansible_user=your_username
```

### 2. Run the Playbook

```bash
# Update all servers
ansible-playbook -i inventory.ini patch_ubuntu.yml

# Update specific group
ansible-playbook -i inventory.ini patch_ubuntu.yml --limit web_servers

# Update specific server
ansible-playbook -i inventory.ini patch_ubuntu.yml --limit server1.example.com
```

### 3. Verify Updates

```bash
# Check system uptime (will show recent reboot if kernel was updated)
ansible servers -i inventory.ini -m shell -a "uptime"

# Check for pending updates
ansible servers -i inventory.ini -m shell -a "apt list --upgradable"
```

## What the Playbook Does

1. **Updates Package Cache**: Refreshes APT repository information (valid for 1 hour)
2. **Upgrades All Packages**: Updates all installed packages to their latest versions
3. **Checks for Reboot**: Detects if `/var/run/reboot-required` exists
4. **Reboots System**: If kernel or critical updates require it
   - Connection timeout: 5 seconds
   - Reboot timeout: 300 seconds (5 minutes)
   - Post-reboot delay: 30 seconds
   - Verifies system is up with `uptime` command
5. **Cleans Up**: Removes packages that are no longer required (dependencies)

## Reboot Behavior

### When Reboot Occurs

The playbook automatically reboots when:
- Kernel updates are installed
- System libraries requiring reboot are updated
- `/var/run/reboot-required` file is present

### Reboot Settings

| Parameter | Value | Description |
|-----------|-------|-------------|
| `connect_timeout` | 5 seconds | Time to wait for initial connection |
| `reboot_timeout` | 300 seconds | Maximum time to wait for reboot completion |
| `pre_reboot_delay` | 0 seconds | Delay before initiating reboot |
| `post_reboot_delay` | 30 seconds | Wait time after system comes back |
| `test_command` | `uptime` | Command to verify system is operational |

### No Reboot Scenario

If no reboot is required, the playbook:
- Skips the reboot task
- Continues to package cleanup
- Completes quickly

## Advanced Usage

### Dry Run (Check Mode)

Preview what would be updated without making changes:

```bash
ansible-playbook -i inventory.ini patch_ubuntu.yml --check
```

### Update Specific Packages Only

To update only specific packages (requires modifying the playbook):

```yaml
- name: Update specific packages
  ansible.builtin.apt:
    name:
      - nginx
      - postgresql
    state: latest
```

### Disable Automatic Reboot

Create a custom playbook without the reboot task or set a condition:

```yaml
- name: Reboot the Debian or Ubuntu server
  reboot:
    msg: "Reboot initiated by Ansible due to kernel updates"
    connect_timeout: 5
    reboot_timeout: 300
    pre_reboot_delay: 0
    post_reboot_delay: 30
    test_command: uptime
  when: reboot_required_file.stat.exists and auto_reboot | default(true)
```

Then run with:
```bash
ansible-playbook -i inventory.ini patch_ubuntu.yml -e "auto_reboot=false"
```

### Verbose Output

```bash
ansible-playbook -i inventory.ini patch_ubuntu.yml -vv
```

## Scheduling with Cron

### Option 1: Ansible Control Machine

Schedule updates from your control machine:

```bash
# Update all servers weekly on Sunday at 2 AM
0 2 * * 0 cd /path/to/ansible && ansible-playbook -i inventory.ini patch_ubuntu.yml
```

### Option 2: Using ansible-pull on Targets

Configure targets to pull and run updates:

```bash
# On each target server
0 2 * * 0 ansible-pull -U https://git.example.com/ansible.git updates/patch_ubuntu.yml
```

## Best Practices

### Maintenance Windows

1. **Schedule During Off-Peak Hours**: Run updates during low-traffic periods
2. **Stagger Updates**: Use `serial` to update hosts in batches:

```yaml
- hosts: all
  serial: 2  # Update 2 hosts at a time
  gather_facts: yes
  become: yes
  tasks:
    # ... existing tasks
```

3. **Test in Staging First**: Always test updates in a staging environment

### Pre-Update Checks

Add pre-update tasks to verify system health:

```yaml
- name: Check disk space
  ansible.builtin.shell: df -h / | awk 'NR==2 {print $5}' | sed 's/%//'
  register: disk_usage
  failed_when: disk_usage.stdout | int > 90
```

### Post-Update Validation

Add validation tasks after updates:

```yaml
- name: Verify critical services are running
  ansible.builtin.service:
    name: "{{ item }}"
    state: started
  loop:
    - nginx
    - postgresql
    - docker
```

### Backup Before Updates

```bash
# Take VM snapshot before updates (if using virtualization)
# Or backup critical data
ansible-playbook backup_playbook.yml
ansible-playbook patch_ubuntu.yml
```

## Troubleshooting

### Package Lock Issues

```
Could not get lock /var/lib/dpkg/lock-frontend
```

**Solution**: Another package manager is running. Wait or:

```bash
# Check what's using apt
ansible servers -i inventory.ini -b -m shell -a "lsof /var/lib/dpkg/lock-frontend"

# If safe, kill the process
sudo killall apt apt-get
```

### Network Timeout During Updates

```
Failed to download packages
```

**Solution**: 
- Check internet connectivity
- Verify DNS resolution
- Check APT mirror availability
- Increase timeout in playbook

### Reboot Hangs

```
Timed out waiting for system to reboot
```

**Solution**:
- Increase `reboot_timeout` value
- Check if system is actually rebooting
- Verify SSH access after manual reboot

### Held Packages

Some packages may be held back:

```bash
# Check held packages
ansible servers -i inventory.ini -m shell -a "apt-mark showhold"

# Unhold if necessary
ansible servers -i inventory.ini -b -m shell -a "apt-mark unhold package_name"
```

## Security Considerations

- **Automatic Reboots**: Ensure services are configured to start automatically
- **Service Disruption**: Updates will cause temporary service interruptions
- **Kernel Updates**: Always test kernel updates in non-production first
- **Unattended Upgrades**: Consider enabling for security updates only
- **Backup Strategy**: Always have backups before major updates

## Integration with Other Playbooks

This playbook is commonly run:
- **Before** deploying new applications
- **After** initial server provisioning
- **As** part of regular maintenance schedules
- **Before** security audits

Example workflow:
```bash
# 1. Update systems
ansible-playbook updates/patch_ubuntu.yml

# 2. Install Docker
ansible-playbook docker/install_docker.yml

# 3. Deploy applications
ansible-playbook deploy_app.yml
```

## Monitoring Updates

### Check Update History

```bash
# View apt history
ansible servers -i inventory.ini -m shell -a "grep 'upgrade' /var/log/apt/history.log | tail -20"

# View dpkg log
ansible servers -i inventory.ini -m shell -a "grep 'upgrade' /var/log/dpkg.log | tail -20"
```

### Check Current Package Versions

```bash
ansible servers -i inventory.ini -m shell -a "dpkg -l | grep linux-image"
```

### Verify No Pending Updates

```bash
ansible servers -i inventory.ini -m shell -a "apt list --upgradable 2>/dev/null | grep -v 'Listing'"
```

## Alternative: Unattended Upgrades

For automatic security updates, consider `unattended-upgrades`:

```yaml
- name: Install unattended-upgrades
  ansible.builtin.apt:
    name: unattended-upgrades
    state: present

- name: Configure unattended-upgrades for security only
  ansible.builtin.copy:
    dest: /etc/apt/apt.conf.d/50unattended-upgrades
    content: |
      Unattended-Upgrade::Allowed-Origins {
        "${distro_id}:${distro_codename}-security";
      };
      Unattended-Upgrade::Automatic-Reboot "false";
```

## Additional Resources

- [Ubuntu Server Guide - Package Management](https://ubuntu.com/server/docs/package-management)
- [Debian Package Management](https://www.debian.org/doc/manuals/debian-reference/ch02.en.html)
- [Ansible APT Module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html)
- [Ansible Reboot Module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/reboot_module.html)
- [Main Project README](../README.md)

## Contributing

When modifying this playbook:

1. Test on non-production systems first
2. Verify reboot behavior
3. Test with both kernel and non-kernel updates
4. Update this README with changes
5. Document any new variables or options

## Support

For issues related to:
- **APT/Package Management**: Check Ubuntu/Debian documentation
- **Ansible Playbooks**: See the [main project README](../README.md)
- **System Reboots**: Verify SSH configuration and connectivity
- **Specific Package Issues**: Check package-specific documentation
