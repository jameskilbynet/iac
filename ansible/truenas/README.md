# TrueNAS SCALE Ansible Automation

Ansible playbooks for automating TrueNAS SCALE configuration, including datasets, shares, and system settings.

## Overview

These playbooks provide the same functionality as the Python scripts but integrate better with Ansible workflows and can be used with Semaphore UI for automated deployments.

## Features

- **Configure TrueNAS**: Create datasets with ZFS properties and permissions from CSV
- **Extract Configuration**: Backup current TrueNAS configuration to JSON files
- **Compare Configurations**: Compare settings between multiple TrueNAS hosts

## Prerequisites

- Ansible >= 2.9
- TrueNAS SCALE with API access
- API key generated from TrueNAS Web UI (Account > API Keys)

## Setup

### 1. Generate TrueNAS API Key

1. Log into TrueNAS Web UI
2. Navigate to **Account** > **API Keys**
3. Click **Add** to create a new API key
4. Copy the generated key (you won't be able to see it again)

### 2. Set Environment Variable

```bash
export TRUENAS_API_KEY="your-api-key-here"
```

### 3. Configure Inventory

Edit `inventory.ini` and add your TrueNAS host(s):

```ini
[truenas]
truenas.example.com
# or
192.168.1.100

[truenas:vars]
ansible_connection=local
ansible_python_interpreter=/usr/bin/python3
```

## Usage

### Configure TrueNAS from CSV

Create datasets and set permissions based on the CSV configuration file:

```bash
ansible-playbook -i inventory.ini configure_truenas.yml
```

**Optional: Enable NFS share creation**

```bash
ansible-playbook -i inventory.ini configure_truenas.yml -e "create_nfs_shares=true"
```

**Use a different CSV file**

```bash
ansible-playbook -i inventory.ini configure_truenas.yml -e "config_csv_path=/path/to/custom.csv"
```

**Use a different parent pool**

```bash
ansible-playbook -i inventory.ini configure_truenas.yml -e "parent_pool=mypool"
```

### Extract Configuration (Backup)

Extract and save current configuration to JSON files:

```bash
ansible-playbook -i inventory.ini extract_config.yml
```

This creates `./extracted_configs/<hostname>/` with:
- `pools.json` - Pool configurations
- `datasets.json` - Dataset properties and settings
- `nfs_shares.json` - NFS share configurations
- `smb_shares.json` - SMB/CIFS share configurations

### Compare Configurations

Compare configurations across multiple TrueNAS hosts:

```bash
ansible-playbook -i inventory.ini compare_config.yml
```

## CSV Configuration Format

The CSV file must have the following columns:

```csv
dataset,share_name,description,sync,recordsize,compression,atime,acl_type,owner,group,permissions
```

**Example:**

```csv
docker/appdata,docker-appdata,General Docker application data,standard,128K,lz4,off,POSIX,1000,1000,770
docker/config,docker-config,Docker container configuration files,standard,16K,lz4,off,POSIX,1000,1000,770
```

### Column Descriptions

- **dataset**: Dataset path relative to parent pool
- **share_name**: Descriptive name for the share
- **description**: Human-readable description
- **sync**: ZFS sync setting (`standard`, `always`, `disabled`)
- **recordsize**: ZFS recordsize (`16K`, `128K`, `1M`, etc.)
- **compression**: Compression algorithm (`lz4`, `zstd`, `gzip`, `off`)
- **atime**: Access time updates (`on`, `off`)
- **acl_type**: ACL type (`POSIX`, `NFSv4`)
- **owner**: Numeric UID or username
- **group**: Numeric GID or group name
- **permissions**: Octal permissions (e.g., `770`, `755`)

## Playbook Variables

### configure_truenas.yml

| Variable | Default | Description |
|----------|---------|-------------|
| `truenas_api_key` | `$TRUENAS_API_KEY` | API key for authentication |
| `truenas_base_url` | `https://{{ inventory_hostname }}` | TrueNAS API URL |
| `truenas_validate_certs` | `false` | SSL certificate validation |
| `config_csv_path` | `../../scripts/truenas/docker_share_config.csv` | Path to CSV config |
| `parent_pool` | `docker` | Base pool name |
| `create_nfs_shares` | `false` | Create NFS shares for datasets |

### extract_config.yml

| Variable | Default | Description |
|----------|---------|-------------|
| `output_dir` | `./extracted_configs` | Directory for extracted configs |

## Integration with Semaphore UI

These playbooks are designed to work with Semaphore UI:

1. Add TrueNAS hosts to your inventory
2. Store `TRUENAS_API_KEY` as an environment variable in Semaphore
3. Create a task template for each playbook
4. Schedule automated configuration deployments

## Security Considerations

- **Never commit API keys to version control**
- Store API keys in environment variables or secret management systems
- Use `ansible-vault` for sensitive inventory variables
- Enable certificate validation in production (`truenas_validate_certs: true`)
- Restrict API key permissions to minimum required scope

## Troubleshooting

### API Authentication Fails

```bash
# Verify API key is set
echo $TRUENAS_API_KEY

# Test API connectivity manually
curl -k -H "Authorization: Bearer $TRUENAS_API_KEY" \
  https://truenas.example.com/api/v2.0/pool
```

### Dataset Already Exists

The playbook handles existing datasets gracefully (status code 409). It will skip creation and continue with permission updates.

### Permission Denied

Ensure the API key has sufficient permissions:
- Full Admin access, or
- Specific permissions for pool/dataset management and sharing

### CSV Parse Errors

Ensure your CSV:
- Has a header row matching the required columns
- Uses commas as delimiters
- Has no empty required fields
- Uses UTF-8 encoding

## Advanced Usage

### Dry Run (Check Mode)

```bash
ansible-playbook -i inventory.ini configure_truenas.yml --check
```

### Verbose Output

```bash
ansible-playbook -i inventory.ini configure_truenas.yml -vvv
```

### Target Specific Host

```bash
ansible-playbook -i inventory.ini configure_truenas.yml --limit truenas01
```

### Use Different API Key

```bash
TRUENAS_API_KEY="different-key" ansible-playbook -i inventory.ini configure_truenas.yml
```

## Related Files

- Python equivalent: `../../scripts/truenas_config_sync.py`
- Configuration data: `../../scripts/truenas/docker_share_config.csv`
- Requirements: See repository root WARP.md

## API Reference

TrueNAS SCALE API documentation:
- Base URL: `https://<hostname>/api/docs/`
- Datasets: `/api/v2.0/pool/dataset`
- NFS Shares: `/api/v2.0/sharing/nfs`
- SMB Shares: `/api/v2.0/sharing/smb`
