# TrueNAS Ansible Quick Start Guide

## Setup (One-time)

```bash
# 1. Generate API key in TrueNAS Web UI
#    Navigate to: Account → API Keys → Add

# 2. Set environment variables
export TRUENAS_HOST="192.168.4.84"
export TRUENAS_API_KEY="1-TzltwHcgtNGKqKf2nqCx6WfDKo7yWmT57GTr68tDd7dVk6VkAiu2BOU1jsCDkFWM"
export TRUENAS_POOL="tank"  # optional
```

## Common Commands

### All-in-One Setup

```bash
# Create datasets + NFS shares
./setup_truenas.sh nfs

# Create datasets + SMB shares
./setup_truenas.sh smb

# Create datasets + both NFS and SMB shares
./setup_truenas.sh both
```

### Individual Playbooks

```bash
# Create datasets only
ansible-playbook create_datasets.yml

# Create NFS shares
ansible-playbook create_shares.yml

# Create SMB shares
ansible-playbook create_shares.yml -e "share_type=smb"
```

### Custom Configuration

```bash
# Use custom CSV file
ansible-playbook create_datasets.yml -e "csv_file_path=/path/to/custom.csv"

# Custom NFS network
ansible-playbook create_shares.yml -e "nfs_network=10.0.0.0/8"

# Custom NFS maproot
ansible-playbook create_shares.yml -e "nfs_maproot_user=myuser" -e "nfs_maproot_group=mygroup"
```

### Validation

```bash
# Dry run (check mode)
ansible-playbook create_datasets.yml --check

# Verbose output
ansible-playbook create_datasets.yml -v

# Very verbose (for debugging)
ansible-playbook create_datasets.yml -vvv

# Syntax check
ansible-playbook create_datasets.yml --syntax-check
```

## File Structure

```
ansible/truenas/
├── create_datasets.yml          # Creates ZFS datasets
├── create_shares.yml            # Creates NFS/SMB shares
├── docker_share_config.csv      # Dataset configuration
├── setup_truenas.sh             # Automated setup script
├── inventory.yml.example        # Multi-host inventory template
├── README.md                    # Full documentation
└── QUICKSTART.md               # This file
```

## CSV Format

```csv
dataset,share_name,description,sync,recordsize,compression,atime,acl_type,owner,group,permissions
docker/appdata,docker-appdata,General Docker application data,standard,128K,lz4,off,POSIX,1000,1000,770
```

## Troubleshooting

| Error | Solution |
|-------|----------|
| `Status code was 401` | Check API key is correct and not expired |
| `Failed to connect` | Verify `TRUENAS_HOST` is correct and accessible |
| `Dataset already exists` | Normal - playbook skips existing datasets |
| `Permission errors` | Verify UIDs/GIDs exist on TrueNAS |
| `Share creation failed` | Ensure datasets exist first (run `create_datasets.yml`) |

## Verification Steps

1. **Check datasets:**
   - Web UI: Storage → Datasets
   - CLI: `zfs list`

2. **Check NFS shares:**
   - Web UI: Shares → Unix (NFS) Shares
   - CLI: `cat /etc/exports`

3. **Check SMB shares:**
   - Web UI: Shares → Windows (SMB) Shares
   - CLI: `smbstatus`

4. **Test mount (NFS):**
   ```bash
   showmount -e $TRUENAS_HOST
   sudo mount -t nfs $TRUENAS_HOST:/mnt/tank/docker/appdata /mnt/test
   ```

5. **Test mount (SMB):**
   ```bash
   smbclient -L $TRUENAS_HOST -N
   sudo mount -t cifs //$TRUENAS_HOST/docker-appdata /mnt/test -o guest
   ```

## Common Workflows

### Initial Setup
```bash
export TRUENAS_HOST="192.168.1.100"
export TRUENAS_API_KEY="your-key"
./setup_truenas.sh both
```

### Update Existing Configuration
```bash
# Edit CSV file, then re-run
vim docker_share_config.csv
ansible-playbook create_datasets.yml  # Creates only new datasets
ansible-playbook create_shares.yml    # Creates only new shares
```

### Create Test Environment
```bash
# Create filtered CSV for testing
head -1 docker_share_config.csv > test.csv
grep "portainer\|grafana" docker_share_config.csv >> test.csv

# Deploy to test pool
export TRUENAS_POOL="test-pool"
ansible-playbook create_datasets.yml -e "csv_file_path=test.csv"
```

## Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `TRUENAS_HOST` | Yes | - | TrueNAS hostname or IP |
| `TRUENAS_API_KEY` | Yes | - | API key from TrueNAS |
| `TRUENAS_POOL` | No | `tank` | ZFS pool name |

## Additional Variables (Playbook Level)

| Variable | Default | Description |
|----------|---------|-------------|
| `share_type` | `nfs` | Share type: `nfs` or `smb` |
| `nfs_network` | `192.168.1.0/24` | NFS allowed network |
| `nfs_maproot_user` | `root` | NFS maproot user |
| `nfs_maproot_group` | `wheel` | NFS maproot group |
| `csv_file_path` | `docker_share_config.csv` | Path to CSV file |

## Quick Links

- [Full Documentation](README.md)
- [TrueNAS API Docs](https://www.truenas.com/docs/api/)
- [Ansible URI Module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/uri_module.html)
