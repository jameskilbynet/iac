# TrueNAS Automation with Ansible

These playbooks automate the creation of TrueNAS datasets and shares using the TrueNAS API, configured from a CSV file.

## Playbooks

- **`create_datasets.yml`** - Creates ZFS datasets with custom properties (compression, recordsize, etc.)
- **`create_shares.yml`** - Creates NFS or SMB shares for the datasets

## Prerequisites

- Ansible installed on your system
- TrueNAS SCALE system with API access
- TrueNAS API key (generate from Web UI > Account > API Keys)

## Setup

### 1. Generate TrueNAS API Key

1. Log into your TrueNAS Web UI
2. Navigate to **Account** → **API Keys**
3. Click **Add** to create a new API key
4. Save the generated key securely (it will only be shown once)

### 2. Configure Environment Variables

```bash
export TRUENAS_HOST="truenas.example.com"  # or IP address
export TRUENAS_API_KEY="your-api-key-here"
export TRUENAS_POOL="tank"  # optional, defaults to 'tank'
```

## Usage

### Quick Setup (Recommended)

Use the automated setup script to create datasets and shares in one step:

```bash
# Create datasets and both NFS + SMB shares
./setup_truenas.sh both

# Create datasets and NFS shares only
./setup_truenas.sh nfs

# Create datasets and SMB shares only
./setup_truenas.sh smb
```

### Dataset Creation

Run the dataset creation playbook with the default CSV file (`docker_share_config.csv`):

```bash
ansible-playbook create_datasets.yml
```

### Share Creation

Create NFS shares (default):

```bash
ansible-playbook create_shares.yml
```

Create SMB/CIFS shares:

```bash
ansible-playbook create_shares.yml -e "share_type=smb"
```

Customize NFS network access:

```bash
ansible-playbook create_shares.yml -e "nfs_network=10.0.0.0/8"
```

Specify maproot user/group for NFS:

```bash
ansible-playbook create_shares.yml -e "nfs_maproot_user=myuser" -e "nfs_maproot_group=mygroup"
```

### Custom CSV File

Specify a different CSV file:

```bash
ansible-playbook create_datasets.yml -e "csv_file_path=/path/to/custom.csv"
```

### Dry Run (Check Mode)

Preview what would be created without making changes:

```bash
ansible-playbook create_datasets.yml --check
```

### Verbose Output

Run with verbose output for debugging:

```bash
ansible-playbook create_datasets.yml -v
# or for more detail
ansible-playbook create_datasets.yml -vvv
```

## CSV File Format

The CSV file must have the following columns:

| Column | Description | Example |
|--------|-------------|---------|
| `dataset` | Dataset path (relative to pool) | `docker/paperless-ngx/data` |
| `share_name` | Human-readable share name | `paperless-ngx-data` |
| `description` | Dataset description | `Paperless-ngx document storage` |
| `sync` | Sync mode | `standard` |
| `recordsize` | Record size | `128K` |
| `compression` | Compression algorithm | `lz4` |
| `atime` | Access time updates | `off` |
| `acl_type` | ACL type | `POSIX` |
| `owner` | Owner UID | `1000` |
| `group` | Group GID | `1000` |
| `permissions` | Unix permissions | `770` |

### Example CSV Row

```csv
docker/paperless-ngx/data,paperless-ngx-data,Paperless-ngx document storage,standard,128K,lz4,off,POSIX,1000,1000,770
```

## What the Playbooks Do

### create_datasets.yml

1. **Validates** environment variables (TRUENAS_HOST, TRUENAS_API_KEY)
2. **Reads** the CSV file containing dataset configurations
3. **Tests** API connectivity to TrueNAS
4. **Retrieves** existing datasets to avoid duplicates
5. **Creates** datasets with specified properties:
   - Sync mode
   - Record size
   - Compression
   - Access time settings
   - ACL type
6. **Sets** ownership and permissions on each dataset
7. **Reports** results with summary

### create_shares.yml

1. **Validates** environment variables (TRUENAS_HOST, TRUENAS_API_KEY)
2. **Reads** the CSV file containing dataset configurations
3. **Tests** API connectivity to TrueNAS
4. **Retrieves** existing shares to avoid duplicates
5. **Creates** NFS or SMB shares for each dataset:
   - **NFS**: Configures network access, maproot user/group, read/write permissions
   - **SMB**: Configures share name, browsability, ACLs, shadow copies
6. **Enables and starts** the appropriate service (NFS or SMB)
7. **Reports** results with summary

## Features

- **Idempotent**: Skips datasets that already exist
- **Error Handling**: Continues on errors with `ignore_errors: true`
- **Retries**: Permission changes retry up to 3 times with 2-second delays
- **URL Encoding**: Properly handles nested dataset paths with URL encoding
- **Validation**: Ensures required environment variables are set before execution

## Troubleshooting

### Authentication Failed

```
FAILED - Status code was 401
```

**Solution**: Verify your API key is correct and not expired. Generate a new key if needed.

### Connection Refused

```
FAILED - Failed to connect to truenas.example.com
```

**Solution**: 
- Verify `TRUENAS_HOST` is correct
- Ensure TrueNAS is accessible from your network
- Check if you need to use IP address instead of hostname

### Dataset Already Exists

The playbook automatically skips existing datasets. If you see fewer datasets created than expected, they likely already exist.

### Permission Errors

```
FAILED - Set dataset permissions
```

**Solution**: 
- Verify the UIDs/GIDs exist on your TrueNAS system
- Check that the pool has enough space
- Ensure the API key has sufficient permissions

### CSV Format Issues

```
FAILED - Read CSV file
```

**Solution**:
- Verify the CSV file path is correct
- Ensure the CSV has all required columns
- Check for proper CSV formatting (commas, no missing fields)

### Share Creation Errors

```
FAILED - Create NFS/SMB shares
```

**Solution**:
- Ensure datasets exist before creating shares (run `create_datasets.yml` first)
- Verify the dataset paths are correct: `/mnt/pool/dataset`
- For NFS: Check network CIDR format (e.g., `192.168.1.0/24`)
- For SMB: Ensure share names are unique and valid (no special characters)

### Service Start Failures

```
FAILED - Enable/Start NFS/SMB service
```

**Solution**:
- Check if the service is already running
- Review TrueNAS system logs for service errors
- Verify TrueNAS network configuration
- For SMB: Ensure Active Directory/LDAP settings are correct if using domain authentication

## Security Notes

- **API Key Storage**: Never commit API keys to version control
- **Use Environment Variables**: Always use environment variables for sensitive data
- **SSL Verification**: The playbook disables SSL verification (`validate_certs: false`). For production, consider:
  - Using valid SSL certificates on TrueNAS
  - Setting `validate_certs: true` in the playbook

## Example Workflow

### Complete Setup (Datasets + Shares)

```bash
# Set environment variables
export TRUENAS_HOST="192.168.1.100"
export TRUENAS_API_KEY="1-abc123def456..."
export TRUENAS_POOL="storage"

# Step 1: Create datasets
ansible-playbook create_datasets.yml

# Step 2: Create NFS shares
ansible-playbook create_shares.yml

# Or create SMB shares instead
ansible-playbook create_shares.yml -e "share_type=smb"

# Check TrueNAS Web UI to verify datasets and shares were created
```

### Dataset Only

```bash
export TRUENAS_HOST="192.168.1.100"
export TRUENAS_API_KEY="1-abc123def456..."
export TRUENAS_POOL="tank"

ansible-playbook create_datasets.yml
```

## Advanced Usage

### Multiple TrueNAS Hosts

For managing multiple TrueNAS systems, use the inventory file:

```bash
# Copy the example inventory
cp inventory.yml.example inventory.yml

# Edit with your TrueNAS hosts
vim inventory.yml

# Set API keys for each environment
export TRUENAS_PROD_API_KEY="your-prod-key"
export TRUENAS_STAGING_API_KEY="your-staging-key"
export TRUENAS_DEV_API_KEY="your-dev-key"

# Target specific environment
ansible-playbook -i inventory.yml create_datasets.yml --limit production

# Target specific host
ansible-playbook -i inventory.yml create_datasets.yml --limit truenas-prod-01

# Create SMB shares on all production systems
ansible-playbook -i inventory.yml create_shares.yml --limit production -e "share_type=smb"
```

### Create Only Specific Datasets

Modify the CSV file to include only the datasets you want to create, or use `grep` to filter:

```bash
# Create a filtered CSV
head -1 docker_share_config.csv > filtered.csv
grep "paperless" docker_share_config.csv >> filtered.csv

# Run with filtered CSV
ansible-playbook create_datasets.yml -e "csv_file_path=filtered.csv"
```

### Integration with CI/CD

The playbook can be integrated into CI/CD pipelines:

```bash
# GitLab CI example
script:
  - export TRUENAS_HOST=$CI_TRUENAS_HOST
  - export TRUENAS_API_KEY=$CI_TRUENAS_API_KEY
  - ansible-playbook ansible/truenas/create_datasets.yml
```

## Related Resources

- [TrueNAS API Documentation](https://www.truenas.com/docs/api/)
- [Ansible URI Module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/uri_module.html)
- [TrueNAS SCALE Dataset Management](https://www.truenas.com/docs/scale/scaletutorials/storage/datasets/)
