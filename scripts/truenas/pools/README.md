# TrueNAS Scale Pool Management

This directory contains scripts for managing TrueNAS Scale storage pools via the REST API. The scripts provide comprehensive functionality for creating, listing, monitoring, and managing ZFS storage pools through CSV-based bulk operations and interactive commands.

## Overview

Storage pools are the foundation of ZFS storage in TrueNAS Scale. These scripts allow you to:

- **List and Monitor**: View all pools with status, health, and capacity information
- **Create Pools**: Define complex pool topologies through CSV files
- **Pool Maintenance**: Start scrubs, export/import pools, and manage pool health
- **Disk Management**: List available disks and plan pool configurations
- **Safety Features**: Dry-run mode, confirmation prompts, and detailed logging

## Quick Start

### Prerequisites

- TrueNAS Scale system with API access enabled
- API key generated in TrueNAS (System Settings > General > API Keys)
- `curl` command available on your system
- `bash` shell (version 4.0 or later recommended)
- Optional: `jq` for enhanced JSON parsing and formatting

### Basic Setup

1. **Copy the configuration template**:
   ```bash
   cp config.env.template config.env
   ```

2. **Edit configuration with your TrueNAS details**:
   ```bash
   # Edit config.env
   TRUENAS_HOST="https://192.168.1.100"
   TRUENAS_API_KEY="your-api-key-here"
   VERIFY_SSL="true"
   ```

3. **Make script executable**:
   ```bash
   chmod +x truenas_pool_manager.sh
   ```

### Basic Usage Examples

```bash
# List all storage pools
./truenas_pool_manager.sh list

# Show detailed status for a specific pool
./truenas_pool_manager.sh status tank

# List available disks for pool creation
./truenas_pool_manager.sh disks

# Preview pool creation from CSV (dry run)
./truenas_pool_manager.sh --dry-run create example_pools.csv

# Create pools from CSV file
./truenas_pool_manager.sh create example_pools.csv

# Start a scrub on a pool
./truenas_pool_manager.sh scrub tank

# Export a pool (with confirmation)
./truenas_pool_manager.sh export oldpool
```

## Script Commands

### `list` - List All Pools
Lists all storage pools with basic status information.

```bash
./truenas_pool_manager.sh list
```

**Output Format:**
```
NAME            STATUS     HEALTH          SIZE            AVAILABLE       
----            ------     ------          ----            ---------       
tank            ONLINE     HEALTHY         10.9T           8.2T            
backup          ONLINE     HEALTHY         5.4T            3.1T            
```

### `status [pool_name]` - Detailed Pool Status
Shows detailed status information for one or all pools.

```bash
# Status for all pools
./truenas_pool_manager.sh status

# Status for specific pool
./truenas_pool_manager.sh status tank
```

**Features:**
- Complete pool configuration
- Vdev topology and health
- Dataset information
- Usage statistics
- Error counts and status

### `create <csv_file>` - Create Pools from CSV
Creates storage pools based on CSV file definitions.

```bash
# Preview creation (recommended first step)
./truenas_pool_manager.sh --dry-run create pools.csv

# Create pools
./truenas_pool_manager.sh create pools.csv

# Skip confirmation prompts
./truenas_pool_manager.sh --force create pools.csv
```

### `scrub <pool_name>` - Start Pool Scrub
Initiates a scrub operation on the specified pool.

```bash
# Interactive scrub with confirmation
./truenas_pool_manager.sh scrub tank

# Force scrub without confirmation
./truenas_pool_manager.sh --force scrub tank

# Dry run to see what would happen
./truenas_pool_manager.sh --dry-run scrub tank
```

### `export <pool_name>` - Export Pool
Exports (removes) a pool from the system. **Data becomes inaccessible until reimported.**

```bash
# Interactive export with confirmation
./truenas_pool_manager.sh export oldpool

# Force export without confirmation
./truenas_pool_manager.sh --force export oldpool
```

### `import` - Find Importable Pools
Scans for pools that can be imported into the system.

```bash
./truenas_pool_manager.sh import
```

### `disks` - List Available Disks
Lists all disks available for pool creation.

```bash
./truenas_pool_manager.sh disks
```

**Output Format:**
```
DEVICE          MODEL           SERIAL          SIZE       TYPE           
------          -----           ------          ----       ----           
sda             ST4000VN008     WCC123456       3.6T       HDD            
nvme0n1         Samsung 980     S1234567890     953.9G     SSD            
```

## CSV File Format

### Required Columns

| Column | Description | Example Values |
|--------|-------------|----------------|
| `name` | Pool name | `tank`, `backup`, `nvme-pool` |
| `topology` | Pool topology definition | `raidz2:sda,sdb,sdc,sdd` |

### Optional Columns

| Column | Description | Example Values | Default |
|--------|-------------|----------------|---------|
| `encryption` | Encryption settings | `false`, `true`, `passphrase:secret123` | `false` |
| `compression` | Compression algorithm | `lz4`, `gzip`, `zstd`, `lzjb` | None |
| `atime` | Access time updates | `on`, `off` | None |
| `checksum` | Checksum algorithm | `sha256`, `sha512`, `blake3` | None |
| `dedup` | Deduplication | `on`, `off` | `off` |
| `recordsize` | Record size | `128K`, `1M`, `64K` | None |

### Topology Format

The `topology` column defines how disks are organized in the pool:

#### Simple Topologies
```csv
name,topology
stripe-pool,sda,sdb,sdc
mirror-pool,mirror:sda,sdb
raidz1-pool,raidz1:sda,sdb,sdc
raidz2-pool,raidz2:sda,sdb,sdc,sdd
raidz3-pool,raidz3:sda,sdb,sdc,sdd,sde
```

#### Complex Topologies
You can combine multiple vdevs by separating them with spaces:
```csv
name,topology
mixed-pool,raidz2:sda,sdb,sdc,sdd mirror:sde,sdf
complex-pool,raidz1:sda,sdb,sdc raidz1:sdd,sde,sdf mirror:sdg,sdh
```

#### Encryption Options

| Format | Description | Security Level |
|--------|-------------|----------------|
| `false` | No encryption | None |
| `true` | Auto-generated key | High |
| `passphrase:your_password` | Passphrase-based | Medium-High |

**Security Note**: Passphrase-based encryption allows easier key recovery but requires the passphrase to be in the CSV file. Auto-generated keys provide better security but require proper key backup procedures.

## Example CSV Files

### Basic Pools (`example_pools.csv`)
```csv
name,topology,encryption,compression,atime,checksum,dedup,recordsize
tank,raidz2:sda,sdb,sdc,sdd,false,lz4,on,sha256,off,128K
backup,mirror:sde,sdf,true,gzip,off,sha512,off,1M
fast,raidz1:nvme0n1,nvme1n1,nvme2n1,false,lz4,on,blake3,off,64K
secure,mirror:sdg,sdh,passphrase:MySecurePassphrase123,zstd,off,sha256,off,128K
```

### Test Configuration (`test_pools.csv`)
```csv
name,topology,encryption,compression
testpool,mirror:sda,sdb,false,lz4
simplepool,sdc,sdd,sde,false,
```

## Common Options

All commands support these standard options:

| Option | Description |
|--------|-------------|
| `-c, --config FILE` | Specify configuration file (default: config.env) |
| `--dry-run` | Show what would be done without executing |
| `--force` | Skip confirmation prompts |
| `-v, --verbose` | Enable detailed logging and debug output |
| `-h, --help` | Show detailed usage information |

## Configuration File

Create `config.env` from the template:

```bash
# TrueNAS connection settings
TRUENAS_HOST="https://192.168.1.100"
TRUENAS_API_KEY="your-api-key-here"
VERIFY_SSL="true"
```

### Configuration Options

| Variable | Description | Example |
|----------|-------------|---------|
| `TRUENAS_HOST` | TrueNAS server URL | `https://192.168.1.100` |
| `TRUENAS_API_KEY` | API key from TrueNAS | `1-abc123...` |
| `VERIFY_SSL` | SSL certificate verification | `true` or `false` |

## Safety Features

### Built-in Protections
- **Dry Run Mode**: Always test with `--dry-run` first
- **Connection Testing**: Validates API connectivity before operations
- **Input Validation**: Comprehensive CSV format and content validation
- **Confirmation Prompts**: Interactive confirmation for destructive operations
- **Error Handling**: Detailed error reporting with suggested fixes
- **Rollback Information**: Clear logging for tracking changes

### Best Practices

1. **Always use dry-run first**: `--dry-run` to preview changes
   ```bash
   ./truenas_pool_manager.sh --dry-run create pools.csv
   ```

2. **Test connectivity**: Verify connection before bulk operations
   ```bash
   ./truenas_pool_manager.sh list
   ```

3. **Plan disk layout**: Check available disks before pool creation
   ```bash
   ./truenas_pool_manager.sh disks
   ```

4. **Backup existing config**: Export pool configurations before changes
   ```bash
   ./truenas_pool_manager.sh status > current_pools.json
   ```

5. **Use version control**: Track your CSV files in git
   ```bash
   git add pools.csv
   git commit -m "Add new pool configuration"
   ```

## Workflow Examples

### Complete Pool Setup
```bash
# 1. Check configuration and connectivity
./truenas_pool_manager.sh list

# 2. Review available disks
./truenas_pool_manager.sh disks

# 3. Preview pool creation
./truenas_pool_manager.sh --dry-run create example_pools.csv

# 4. Create pools
./truenas_pool_manager.sh create example_pools.csv

# 5. Verify pool creation
./truenas_pool_manager.sh list
./truenas_pool_manager.sh status tank
```

### Pool Maintenance
```bash
# Regular health check
./truenas_pool_manager.sh status

# Start monthly scrub
./truenas_pool_manager.sh scrub tank

# Check for importable pools after hardware changes
./truenas_pool_manager.sh import
```

### Pool Migration
```bash
# Export old pool
./truenas_pool_manager.sh export oldpool

# Find pools to import
./truenas_pool_manager.sh import

# Create new pool configuration
./truenas_pool_manager.sh create new_pools.csv
```

## Error Troubleshooting

### Common Issues

1. **Connection Failed**
   ```
   [ERROR] Failed to connect to TrueNAS API (HTTP 401)
   ```
   **Solutions:**
   - Verify `TRUENAS_HOST` URL format (include https://)
   - Check `TRUENAS_API_KEY` is valid and not expired
   - Confirm network connectivity to TrueNAS system

2. **SSL Certificate Errors**
   ```
   [ERROR] SSL certificate problem: self signed certificate
   ```
   **Solutions:**
   - Set `VERIFY_SSL="false"` for self-signed certificates
   - Consider using proper SSL certificates in production

3. **Disk Not Found**
   ```
   [ERROR] Failed to create pool tank (HTTP 422)
   ```
   **Solutions:**
   - Run `./truenas_pool_manager.sh disks` to verify disk names
   - Check that disks are not already in use
   - Ensure disk names match exactly (case-sensitive)

4. **Pool Already Exists**
   ```
   [ERROR] Pool with this name already exists
   ```
   **Solutions:**
   - Use `./truenas_pool_manager.sh list` to check existing pools
   - Choose a different pool name
   - Export existing pool if replacement is intended

### Debug Mode

Enable verbose logging for detailed troubleshooting:
```bash
./truenas_pool_manager.sh -v list
./truenas_pool_manager.sh -v create pools.csv
```

## Topology Planning Guide

### Choosing Pool Topology

| Use Case | Recommended Topology | Fault Tolerance | Capacity Efficiency |
|----------|---------------------|-----------------|-------------------|
| Maximum Performance | Stripe | None | 100% |
| Balance Performance/Redundancy | Mirror | 1 disk per mirror | 50% |
| Good Redundancy | RAIDZ1 | 1 disk failure | ~75% (3+ disks) |
| Better Redundancy | RAIDZ2 | 2 disk failures | ~66% (4+ disks) |
| Best Redundancy | RAIDZ3 | 3 disk failures | ~60% (5+ disks) |

### Disk Recommendations

| Pool Type | Minimum Disks | Recommended Disks | Notes |
|-----------|---------------|------------------|-------|
| Stripe | 1 | 2-3 | No redundancy - use only for temporary data |
| Mirror | 2 | 2 | Can add more disks to mirror group |
| RAIDZ1 | 3 | 3-8 | Good balance of space and redundancy |
| RAIDZ2 | 4 | 6-10 | Recommended for most production use |
| RAIDZ3 | 5 | 7-12 | Best for critical data |

### Performance Considerations

- **Random I/O**: Mirrors perform better than RAIDZ
- **Sequential I/O**: RAIDZ can match or exceed mirror performance
- **Disk Types**: Don't mix HDD and SSD in the same vdev
- **Pool Width**: More vdevs = better performance
- **Record Size**: Match to workload (128K default, 1M for sequential)

## Integration Examples

### CI/CD Integration
```bash
# Example pipeline step
./truenas_pool_manager.sh --dry-run create production_pools.csv
./truenas_pool_manager.sh --force create production_pools.csv

# Verify deployment
./truenas_pool_manager.sh status | grep ONLINE || exit 1
```

### Monitoring Integration
```bash
# Health check script
#!/bin/bash
POOLS=$(./truenas_pool_manager.sh list | grep -v HEALTHY | wc -l)
if [ $POOLS -gt 1 ]; then
    echo "CRITICAL: Unhealthy pools detected"
    ./truenas_pool_manager.sh status
    exit 2
fi
```

### Backup Verification
```bash
# Verify backup pool before starting backup
./truenas_pool_manager.sh status backup | grep -q ONLINE
if [ $? -eq 0 ]; then
    echo "Backup pool healthy, starting backup..."
    # Run backup process
else
    echo "ERROR: Backup pool not healthy"
    exit 1
fi
```

## API Reference

This script uses the TrueNAS Scale REST API v2.0:

- **System Info**: `GET /api/v2.0/system/info`
- **Pool Operations**: 
  - `GET /api/v2.0/pool` (list pools)
  - `GET /api/v2.0/pool/id/{id}` (pool details)
  - `POST /api/v2.0/pool` (create pool)
  - `POST /api/v2.0/pool/id/{id}/export` (export pool)
  - `POST /api/v2.0/pool/scrub` (start scrub)
- **Disk Management**: `GET /api/v2.0/disk`
- **Import Operations**: `GET /api/v2.0/pool/import_find`

## Security Considerations

### API Key Management
- Generate dedicated API keys for automation
- Use least-privilege principles where possible
- Rotate API keys regularly
- Store keys securely (never in version control)

### Network Security
- Use HTTPS for API communication
- Restrict API access to authorized networks
- Consider VPN access for remote management
- Enable proper firewall rules

### Data Protection
- Test scripts in non-production environments first
- Maintain regular backups before pool operations
- Use dry-run mode extensively
- Document all changes for audit trails

## Limitations

- **Pool Creation Only**: This script creates pools but doesn't modify existing pool topology
- **Basic Vdev Support**: Advanced features like special vdevs or logs are not yet supported
- **No Pool Destruction**: Use TrueNAS UI for pool deletion (safety measure)
- **Limited Encryption Options**: Full encryption feature set may require UI configuration

## Contributing

When contributing to this script:

1. **Follow existing patterns**: Maintain consistency with dataset/share scripts
2. **Test thoroughly**: Include both positive and negative test cases
3. **Update documentation**: Keep this README current
4. **Handle errors gracefully**: Provide clear error messages and suggestions
5. **Maintain compatibility**: Ensure changes don't break existing CSV formats

## Support and Resources

- **TrueNAS Documentation**: [https://www.truenas.com/docs/scale/](https://www.truenas.com/docs/scale/)
- **TrueNAS API Documentation**: Available in your TrueNAS UI under System > API Keys
- **Script Help**: Run `./truenas_pool_manager.sh --help` for detailed usage
- **Examples**: Check the example CSV files in this directory
- **ZFS Documentation**: [OpenZFS Documentation](https://openzfs.github.io/openzfs-docs/)

---

**Note**: These scripts are designed for TrueNAS Scale. They may not be compatible with TrueNAS Core (FreeBSD-based) without modifications.