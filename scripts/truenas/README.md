# TrueNAS Scale Automation Scripts

This directory contains automation scripts for managing TrueNAS Scale systems via the REST API. The scripts provide comprehensive functionality for creating, managing, and deleting datasets and network shares through CSV-based bulk operations.

## Overview

TrueNAS Scale automation is divided into two main areas:

- **[Datasets](datasets/)** - ZFS dataset creation and management
- **[Shares](shares/)** - SMB and NFS share creation and management

Both modules follow consistent patterns for configuration, CSV input formats, error handling, and safety features.

## Quick Start

### Prerequisites

- TrueNAS Scale system with API access enabled
- API key generated in TrueNAS (System Settings > General > API Keys)
- `curl` command available on your system
- `python3` (optional, for enhanced JSON parsing and formatting)
- `bash` shell (version 4.0 or later recommended)

### Basic Workflow

1. **Generate API Key** in TrueNAS UI (System Settings > General > API Keys)
2. **Copy configuration template** and add your credentials
3. **Create CSV files** with your resource definitions
4. **Run dry-run** to preview changes
5. **Execute scripts** to create/delete resources

## Directory Structure

```
truenas/
├── README.md                    # This overview file
├── datasets/
│   ├── README.md               # Detailed dataset documentation
│   ├── config.env.template     # Configuration template
│   ├── truenas_dataset_creator.sh    # Create datasets from CSV
│   ├── truenas_dataset_deleter.sh    # Delete datasets from CSV
│   ├── example_datasets.csv    # Example dataset definitions
│   └── test_datasets.csv       # Test dataset examples
└── shares/
    ├── README.md               # Detailed shares documentation  
    ├── config.env.template     # Configuration template
    ├── truenas_share_creator.sh      # Create SMB/NFS shares from CSV
    ├── truenas_share_deleter.sh      # Delete SMB/NFS shares from CSV
    ├── example_shares.csv      # Example share definitions
    └── example_delete_shares.csv     # Example deletion CSV
```

## Common Configuration

Both dataset and share scripts use the same configuration format. Create a `config.env` file in each directory:

```bash
# TrueNAS server URL (include https:// or http://)
TRUENAS_HOST="https://192.168.1.100"

# TrueNAS API Key (generate in System Settings > General > API Keys)
TRUENAS_API_KEY="your-api-key-here"

# SSL Certificate Verification (set to "false" for self-signed certificates)
VERIFY_SSL="true"
```

## Dataset Management

Located in `datasets/` directory - manages ZFS datasets with comprehensive options.

### Key Features
- **Hierarchical Creation**: Automatically creates parent datasets
- **Size Management**: Human-readable size formats (GB, TB, etc.)
- **Encryption Support**: Passphrase or key-based encryption
- **Compression Options**: Multiple compression algorithms
- **Property Control**: Quotas, reservations, record sizes, case sensitivity

### Quick Examples
```bash
cd datasets/
cp config.env.template config.env
# Edit config.env with your settings

# Preview dataset creation
./truenas_dataset_creator.sh --dry-run example_datasets.csv

# Create datasets
./truenas_dataset_creator.sh example_datasets.csv

# Delete datasets (with confirmation)
./truenas_dataset_deleter.sh datasets_to_delete.csv
```

### Dataset CSV Format
```csv
name,pool,comments,compression,quota,encryption
applications,tank,App storage,lz4,500GB,false
media,tank,Media files,lz4,10TB,false
secure,tank,Encrypted data,lz4,1TB,true
```

## Share Management

Located in `shares/` directory - manages SMB and NFS network shares.

### Key Features
- **Dual Protocol**: SMB and NFS shares in one workflow
- **Apple Integration**: Time Machine and macOS-specific options
- **Network Security**: Host and network restrictions for NFS
- **Access Control**: User mapping, guest access, read-only options
- **Advanced Features**: Shadow copies, recycle bins, browsability

### Quick Examples
```bash
cd shares/
cp config.env.template config.env
# Edit config.env with your settings

# Preview share creation
./truenas_share_creator.sh --dry-run example_shares.csv

# Create shares
./truenas_share_creator.sh example_shares.csv

# List existing shares
./truenas_share_deleter.sh --type smb --list
./truenas_share_deleter.sh --type nfs --list

# Delete individual share
./truenas_share_deleter.sh --name "old-share" --type smb
```

### Share CSV Format
```csv
type,name,path,comment,enabled,browsable
smb,media,/mnt/tank/media,Media files,true,true
smb,docs,/mnt/tank/documents,Documents,true,true
nfs,backup,/mnt/tank/backup,Backup storage,true,
```

## Common Script Options

All scripts support these standard options:

| Option | Description |
|--------|-------------|
| `-c, --config FILE` | Specify configuration file (default: config.env) |
| `--dry-run` | Preview changes without making modifications |
| `--skip-existing` | Skip resources that already exist (creator scripts) |
| `--force` | Skip confirmation prompts (deleter scripts) |
| `-v, --verbose` | Enable detailed logging and debug output |
| `-h, --help` | Show detailed usage information |

## Safety Features

### Built-in Protections
- **Dry Run Mode**: Always test with `--dry-run` first
- **Connection Testing**: Validates API connectivity before operations
- **Input Validation**: Comprehensive CSV format and content validation
- **Confirmation Prompts**: Interactive confirmation for deletions
- **Error Handling**: Detailed error reporting with suggested fixes
- **Rollback Information**: Clear logging for tracking changes

### Best Practices
1. **Always use dry-run first**: `--dry-run` to preview changes
2. **Test with small batches**: Start with a few resources before bulk operations
3. **Keep backups**: Export existing configurations before major changes
4. **Use version control**: Track your CSV files in git
5. **Secure credentials**: Never commit `config.env` files to version control

## Workflow Examples

### Complete Dataset and Share Setup
```bash
# 1. Create datasets first
cd datasets/
cp config.env.template config.env
# Edit config.env

./truenas_dataset_creator.sh --dry-run datasets.csv
./truenas_dataset_creator.sh datasets.csv

# 2. Create shares on those datasets  
cd ../shares/
cp config.env.template config.env
# Edit config.env (same as datasets)

./truenas_share_creator.sh --dry-run shares.csv
./truenas_share_creator.sh shares.csv
```

### Cleanup and Migration
```bash
# List existing resources
cd shares/
./truenas_share_deleter.sh --type smb --list
./truenas_share_deleter.sh --type nfs --list

# Remove old shares
./truenas_share_deleter.sh old_shares.csv

# Remove old datasets (be careful - this deletes data!)
cd ../datasets/
./truenas_dataset_deleter.sh old_datasets.csv
```

## Error Troubleshooting

### Common Issues

1. **Connection Failed**
   - Verify `TRUENAS_HOST` URL format (include https://)
   - Check `TRUENAS_API_KEY` is valid and not expired
   - Confirm network connectivity to TrueNAS system

2. **SSL Certificate Errors**
   - Set `VERIFY_SSL="false"` for self-signed certificates
   - Consider using proper SSL certificates in production

3. **Permission Denied**
   - Ensure API key has administrative privileges
   - Check that TrueNAS user account has required permissions

4. **Resource Creation Failed**
   - Verify parent resources exist (pools for datasets, datasets for shares)
   - Check resource names don't conflict with existing items
   - Ensure sufficient storage space is available

### Debug Mode

Enable verbose logging for detailed troubleshooting:
```bash
./truenas_dataset_creator.sh -v datasets.csv
./truenas_share_creator.sh -v shares.csv
```

## API Reference

These scripts use the TrueNAS Scale REST API v2.0:

- **System Info**: `GET /api/v2.0/system/info`
- **Pools**: `GET /api/v2.0/pool`
- **Datasets**: `GET/POST/DELETE /api/v2.0/pool/dataset`
- **SMB Shares**: `GET/POST/DELETE /api/v2.0/sharing/smb`
- **NFS Shares**: `GET/POST/DELETE /api/v2.0/sharing/nfs`

## Security Considerations

### API Key Management
- Generate dedicated API keys for automation
- Use least-privilege principles
- Rotate API keys regularly
- Store keys securely (never in version control)

### Network Security
- Use HTTPS for API communication
- Restrict API access to authorized networks
- Consider VPN access for remote management
- Enable proper firewall rules

### Data Protection  
- Test scripts in non-production environments first
- Maintain regular backups before bulk operations
- Use dry-run mode extensively
- Document all changes for audit trails

## Integration and Automation

### CI/CD Integration
```bash
# Example pipeline step
./truenas_dataset_creator.sh --force datasets.csv
./truenas_share_creator.sh --force shares.csv
```

### Monitoring Integration
- Parse script output for monitoring systems
- Set up alerts for failed operations
- Track resource creation metrics
- Monitor API key usage and expiration

### Configuration Management
- Store CSV definitions in version control
- Use templating for environment-specific configs
- Implement approval workflows for production changes
- Maintain change logs and documentation

## Contributing

When contributing to these scripts:

1. **Follow existing patterns**: Maintain consistency with current scripts
2. **Test thoroughly**: Include both positive and negative test cases
3. **Update documentation**: Keep README files current
4. **Handle errors gracefully**: Provide clear error messages and suggestions
5. **Maintain compatibility**: Ensure changes don't break existing CSV formats

## Support and Resources

- **TrueNAS Documentation**: [https://www.truenas.com/docs/scale/](https://www.truenas.com/docs/scale/)
- **TrueNAS API Documentation**: Available in your TrueNAS UI under System > API Keys
- **Script-specific help**: Run any script with `--help` for detailed usage
- **Examples**: Check the example CSV files in each directory

---

**Note**: These scripts are designed for TrueNAS Scale. They may not be compatible with TrueNAS Core (FreeBSD-based) without modifications.