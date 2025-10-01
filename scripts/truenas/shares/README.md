# TrueNAS Share Creator

This script automates the creation of SMB and NFS shares on TrueNAS Scale using the REST API. It reads share definitions from a CSV file and creates them in bulk.

## Features

- **Dual Protocol Support**: Create both SMB and NFS shares from a single CSV file
- **Bulk Operations**: Process multiple shares at once from CSV input
- **Dry Run Mode**: Preview what would be created without making changes
- **Skip Existing**: Optionally skip shares that already exist
- **Comprehensive Logging**: Colored output with debug mode support
- **Robust Error Handling**: Detailed error reporting and validation

## Prerequisites

- TrueNAS Scale system with API access
- API key generated in TrueNAS (System Settings > General > API Keys)
- `curl` command available
- `python3` (optional, for JSON formatting)

## Quick Start

1. Copy the configuration template:
```bash
cp config.env.template config.env
```

2. Edit `config.env` with your TrueNAS details:
```bash
TRUENAS_HOST="https://192.168.1.100"
TRUENAS_API_KEY="your-api-key-here"
VERIFY_SSL="true"
```

3. Create a CSV file with your share definitions (see examples below)

4. Run the script:
```bash
# Dry run first to preview changes
./truenas_share_creator.sh --dry-run shares.csv

# Create the shares
./truenas_share_creator.sh shares.csv
```

## Usage

```bash
./truenas_share_creator.sh [OPTIONS] <csv_file>

OPTIONS:
    -c, --config FILE       Configuration file (default: config.env)
    --dry-run              Show what would be created without actually creating shares
    --skip-existing        Skip shares that already exist
    -v, --verbose          Enable verbose logging
    -h, --help             Show this help message
```

## CSV Format

The CSV file must contain the following required columns:
- `type`: Share type ("smb" or "nfs")  
- `name`: Share name (for SMB) or identifier (for NFS)
- `path`: Full path to the shared directory (must exist on TrueNAS)

### SMB Share Columns

| Column | Required | Description | Values |
|--------|----------|-------------|--------|
| type | Yes | Share type | "smb" |
| name | Yes | Share name (as shown in network) | String |
| path | Yes | Full path to shared directory | /mnt/pool/path |
| comment | No | Description of the share | String |
| enabled | No | Enable/disable share | true/false |
| browsable | No | Show in network browser | true/false |
| recyclable | No | Enable recycle bin | true/false |
| guestok | No | Allow guest access | true/false |
| aapl_name_mangling | No | Apple name mangling | true/false |
| aapl_extensions | No | Apple protocol extensions | true/false |
| aapl_metadata | No | Apple metadata support | true/false |
| shadowcopy | No | Enable shadow copies | true/false |
| ro | No | Read-only access | true/false |

### NFS Share Columns

| Column | Required | Description | Values |
|--------|----------|-------------|--------|
| type | Yes | Share type | "nfs" |
| name | Yes | Share identifier | String |
| path | Yes | Full path to shared directory | /mnt/pool/path |
| comment | No | Description of the share | String |
| enabled | No | Enable/disable share | true/false |
| ro | No | Read-only access | true/false |
| maproot | No | Root user mapping | "root", "nobody", etc |
| mapall | No | All users mapping | "nobody", etc |
| security | No | Security options | String |
| networks | No | Allowed networks | "192.168.1.0/24" or space/comma separated |
| hosts | No | Allowed hosts | "server1 server2" or comma separated |
| alldirs | No | Allow access to all subdirectories | true/false |
| quiet | No | Suppress syslog messages | true/false |

## Example CSV Files

### Basic SMB Shares
```csv
type,name,path,comment,enabled,browsable
smb,media,/mnt/tank/media,Media files,true,true
smb,documents,/mnt/tank/documents,Document storage,true,true
smb,public,/mnt/tank/public,Public shared folder,true,true
```

### Advanced SMB Shares with Apple Support
```csv
type,name,path,comment,enabled,browsable,recyclable,guestok,aapl_name_mangling,aapl_extensions,aapl_metadata,shadowcopy
smb,media-share,/mnt/tank/media,Media files for streaming,true,true,false,false,true,true,true,true
smb,time-machine,/mnt/tank/backups/timemachine,Time Machine backups,true,false,false,false,true,true,true,false
```

### NFS Shares
```csv
type,name,path,comment,enabled,ro,maproot,networks,hosts
nfs,backup-nfs,/mnt/tank/backup,Backup storage via NFS,true,false,root,192.168.1.0/24,
nfs,media-ro,/mnt/tank/media,Read-only media access,true,true,nobody,192.168.1.0/24,server1 server2
```

### Mixed SMB and NFS Shares
```csv
type,name,path,comment,enabled,browsable,recyclable,guestok,ro,maproot,networks,hosts
smb,media-share,/mnt/tank/media,Media files for streaming,true,true,false,false,false,,,
smb,documents,/mnt/tank/documents,Document storage,true,true,true,false,false,,,
nfs,backup-nfs,/mnt/tank/backup,Backup storage via NFS,true,,,,,root,192.168.1.0/24,server.local
nfs,logs,/mnt/tank/logs,System logs via NFS,true,,,,,nobody,192.168.0.0/16,
```

## Configuration File

The `config.env` file contains your TrueNAS connection settings:

```bash
# TrueNAS server URL (include https:// or http://)
TRUENAS_HOST="https://your-truenas-ip-or-hostname"

# TrueNAS API Key (generate in System Settings > General > API Keys)
TRUENAS_API_KEY="your-api-key-here"

# SSL Certificate Verification
VERIFY_SSL="true"  # Set to "false" for self-signed certificates
```

## Examples

### Dry Run (Preview Changes)
```bash
./truenas_share_creator.sh --dry-run example_shares.csv
```

### Create Shares with Verbose Output
```bash
./truenas_share_creator.sh -v shares.csv
```

### Skip Existing Shares
```bash
./truenas_share_creator.sh --skip-existing shares.csv
```

### Use Custom Config File
```bash
./truenas_share_creator.sh -c production.env shares.csv
```

## Important Notes

### Path Requirements
- All paths in the CSV must exist on the TrueNAS system
- Paths should be full absolute paths starting with `/mnt/`
- The underlying datasets/directories must be created before sharing

### SMB Share Names
- SMB share names must be unique across the system
- Avoid special characters in share names
- Share names are case-sensitive

### NFS Network Specifications
- Networks can be specified as IP ranges (192.168.1.0/24) or individual IPs
- Multiple networks/hosts can be space or comma separated
- Leave empty to allow all networks (not recommended for security)

### Permissions
- The script creates shares but does not modify filesystem permissions
- Ensure proper Unix permissions are set on shared directories
- Consider ACLs for complex permission requirements

## Troubleshooting

### Common Issues

1. **Connection Failed**: Verify `TRUENAS_HOST` and `TRUENAS_API_KEY` in config.env
2. **Share Creation Failed**: Check that the path exists and is accessible
3. **Permission Denied**: Ensure the API key has sufficient privileges
4. **SSL Errors**: Set `VERIFY_SSL="false"` for self-signed certificates (not recommended for production)

### Debug Mode
Use `-v` flag for verbose output to see detailed API calls and responses:
```bash
./truenas_share_creator.sh -v shares.csv
```

### Manual API Testing
Test your connection manually:
```bash
curl -H "Authorization: Bearer YOUR_API_KEY" https://your-truenas-ip/api/v2.0/system/info
```

## Security Considerations

- Keep your `config.env` file secure and never commit it to version control
- Use strong API keys and rotate them periodically
- Enable SSL verification in production environments
- Review network restrictions for NFS shares
- Consider using dedicated service accounts for API access

## Related Scripts

- **Dataset Creator**: `../datasets/truenas_dataset_creator.sh` - Create datasets before sharing
- **Share Deleter**: Create shares first, then manage them through the TrueNAS UI or additional scripts

## Contributing

This script follows the same patterns as other TrueNAS automation scripts in this repository. When contributing:

1. Maintain compatibility with the existing CSV format
2. Follow the established error handling patterns
3. Update documentation for new features
4. Test with both SMB and NFS shares