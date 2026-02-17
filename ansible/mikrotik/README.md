# Mikrotik Configuration Backup

Ansible playbook to backup configurations from Mikrotik switches.

## Inventory

The following devices are managed:

| Name | IP Address |
|------|------------|
| mikrotik-sw-1 | 192.168.3.1 |
| mikrotik-sw-2 | 192.168.3.2 |

## Prerequisites

Install the required Ansible collections:

```bash
ansible-galaxy collection install community.routeros ansible.netcommon
```

## Usage

Run the backup playbook:

```bash
ansible-playbook -i inventory.yml backup_config.yml
```

To backup a specific device:

```bash
ansible-playbook -i inventory.yml backup_config.yml --limit mikrotik-sw-1
```

## Output

Configurations are saved to the `configs/` directory with timestamps:

- `<hostname>_full_<timestamp>.rsc` - Complete configuration export
- `<hostname>_compact_<timestamp>.rsc` - Compact export (without defaults)
- `<hostname>_latest.rsc` - Latest compact configuration (overwritten each run)

## SSH Configuration

The playbook uses SSH key authentication with the `admin` user. Ensure your private key (`~/.ssh/id_rsa`) is configured for access to the Mikrotik devices.

If using a different key, update `ansible_ssh_private_key_file` in `inventory.yml`.
