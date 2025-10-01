# TrueNAS Scale Dataset Creator

A comprehensive shell script to automate the creation of ZFS datasets on TrueNAS Scale using the REST API. This tool allows you to define datasets in CSV files and create them in bulk with advanced features like encryption and human-readable sizes.

## Features

- ✅ **Bulk dataset creation** from CSV input files
- ✅ **Child dataset support** with automatic parent creation
- ✅ **Hierarchical processing** ensures parents are created before children
- ✅ **Human-readable sizes** (1GB, 500MB, 2.5TB) for quotas and reservations
- ✅ **Dataset encryption support** with passphrase or auto-generated keys
- ✅ **Comprehensive dataset configuration** support (compression, quotas, permissions)
- ✅ **Dry run mode** to preview operations
- ✅ **Skip existing datasets** option
- ✅ **Pool validation** to ensure target pools exist
- ✅ **Detailed logging** with colored output and verbose mode
- ✅ **Error handling** and recovery with detailed API error reporting
- ✅ **Secure configuration** management

## Files Overview

```
truenas/
├── truenas_dataset_creator.sh     # Main script for dataset creation
├── truenas_dataset_deleter.sh     # Bulk dataset deletion script
├── config.env                     # TrueNAS API configuration
├── example_datasets.csv           # Example CSV input format
└── README.md                      # This documentation
```

## Quick Start

1. **Configure your TrueNAS connection**:
   ```bash
   # Edit config.env with your TrueNAS details
   nano config.env
   ```

2. **Prepare your dataset definitions**:
   ```bash
   # Create your dataset CSV file
   cp example_datasets.csv my_datasets.csv
   # Edit with your dataset definitions
   nano my_datasets.csv
   ```

3. **Test your configuration**:
   ```bash
   # Dry run to see what would be created
   ./truenas_dataset_creator.sh --dry-run my_datasets.csv
   ```

4. **Create the datasets**:
   ```bash
   # Create datasets for real
   ./truenas_dataset_creator.sh my_datasets.csv
   ```

## Configuration

### TrueNAS API Setup

1. **Generate an API Key** in TrueNAS Scale:
   - Navigate to **System Settings** > **General** > **API Keys**
   - Click **Add** to create a new API key
   - Copy the generated key

2. **Configure the script**:
   ```bash
   cp config.env.template config.env
   ```
   
   Edit `config.env`:
   ```bash
   TRUENAS_HOST="https://your-truenas-ip"
   TRUENAS_API_KEY="your-api-key-here"
   VERIFY_SSL="true"  # Set to false for self-signed certificates
   ```

### Input File Format

The script expects CSV files with the following columns:

#### Required Columns
- `name` - Dataset name (will be created as pool/name)
  - For child datasets, use forward slashes: `parent/child` or `parent/child/grandchild`
  - Examples: `applications`, `applications/web`, `media/movies/hd`
- `pool` - Target ZFS pool name

#### Optional Columns

**Basic Dataset Properties:**
- `comments` - Description/comments for the dataset
- `compression` - Compression algorithm (lz4, gzip, zstd, etc.)
- `deduplication` - Deduplication setting (on/off)
- `recordsize` - Record size (4K, 8K, 128K, 1M, etc.)
- `case_sensitivity` - Case sensitivity (sensitive/insensitive)
- `atime` - Access time updates (on/off)
- `exec` - Execute permissions (on/off)

**Size and Quota Fields (Human-Readable!):**
- `quota` - Dataset quota (1GB, 500MB, 2.5TB, or NONE)
- `refquota` - Reference quota (1GB, 500MB, 2.5TB, or NONE)
- `reservation` - Space reservation (100MB, 1GB, or NONE)
- `refreservation` - Reference reservation (100MB, 1GB, or NONE)

**Encryption Fields:**
- `encryption` - Enable encryption (true/false, on/off)
- `encryption_passphrase` - Passphrase for encryption (optional)
- `encryption_algorithm` - Encryption algorithm (optional, defaults to AES-256-GCM)
- `encryption_key_format` - Key format (optional, auto-determined)

#### Example CSV Format
```csv
name,pool,comments,compression,quota,recordsize,encryption,encryption_passphrase
applications,tank,App storage,lz4,10GB,128K,false,
applications/web,tank,Web apps,lz4,5GB,128K,false,
applications/nginx,tank,Nginx config,lz4,1GB,128K,false,
secure_docs,tank,Encrypted documents,lz4,20GB,128K,true,MySecretPass123
auto_encrypted,tank,Auto-encrypted data,lz4,50GB,128K,true,
backup,tank,Backup data,gzip,500GB,1M,false,
media,tank,Media files,lz4,2.5TB,1M,false,
media/movies,tank,Movie collection,lz4,NONE,1M,false,
```

## Script Usage

### Main Dataset Creator

```bash
./truenas_dataset_creator.sh [OPTIONS] <csv_file>
```

#### Options
- `-c, --config FILE` - Configuration file (default: config.env)
- `--dry-run` - Preview operations without creating datasets
- `--skip-existing` - Skip datasets that already exist
- `-v, --verbose` - Enable detailed logging
- `-h, --help` - Show help message

#### Examples
```bash
# Basic usage
./truenas_dataset_creator.sh datasets.csv

# Dry run with verbose output
./truenas_dataset_creator.sh --dry-run -v datasets.csv

# Use custom config and skip existing
./truenas_dataset_creator.sh -c prod.env --skip-existing datasets.csv
```

## Advanced Features

### Human-Readable Size Support

The script now supports intuitive size formats for all quota and reservation fields:

#### Supported Size Formats
- **Raw bytes**: `1073741824`
- **Kilobytes**: `512KB`, `100kb` 
- **Megabytes**: `500MB`, `1.5mb`
- **Gigabytes**: `10GB`, `2.5gb`
- **Terabytes**: `1TB`, `5.2tb`
- **Larger units**: `PB`, `EB`, `ZB`, `YB`
- **No limit**: `NONE` or `none`

#### Size Examples
```csv
name,pool,quota,refquota,reservation
homebase,tank,100GB,80GB,10GB
database,tank,2.5TB,2TB,500GB
logs,tank,50GB,NONE,1GB
temp,tank,10GB,5GB,100MB
```

### Dataset Encryption Support

Create encrypted datasets with automatic key management:

#### Encryption Options
1. **Auto-generated keys** (recommended for security)
2. **Passphrase-based encryption** (easier for manual access)
3. **Mixed configurations** (some encrypted, some not)

#### Encryption Fields
- `encryption`: Set to `true`/`on` to enable encryption
- `encryption_passphrase`: Optional passphrase (auto-generates key if empty)
- Algorithm defaults to **AES-256-GCM** (secure and fast)
- Key format auto-determined (HEX for generated keys, PASSPHRASE for passphrases)

#### Encryption Examples
```csv
name,pool,encryption,encryption_passphrase,comments
secure_files,tank,true,MySecretPass123,Passphrase encrypted
auto_secure,tank,true,,Auto-generated key
public_data,tank,false,,No encryption
```

### Bulk Dataset Deletion

Use the companion deletion script for cleanup:

```bash
# Preview what would be deleted
./truenas_dataset_deleter.sh --dry-run --pool tank

# Delete all datasets from a specific pool (with confirmation)
./truenas_dataset_deleter.sh --pool tank

# Force deletion without prompts (dangerous!)
./truenas_dataset_deleter.sh --pool tank --force
```

## Dataset Configuration Details

### Compression Options
- `lz4` - Fast compression (default for most use cases)
- `gzip` - Better compression ratio, more CPU intensive
- `zstd` - Modern compression with good balance
- `off` - No compression

### Record Size Guidelines
- **4K-16K** - Databases, small random I/O
- **128K** - General purpose (default)
- **1M** - Large files, media, sequential I/O

### Quota/Reservation Values
- **Human-readable**: `1GB`, `500MB`, `2.5TB`, `100KB`
- **Case insensitive**: `1gb`, `500mb`, `2.5tb` all work
- **Decimal support**: `2.5TB`, `1.5GB` supported
- **Raw bytes still work**: `1073741824` for 1GB
- **No limit**: Use `NONE` or `none`
- **Reservations** guarantee space availability

### Boolean Settings
- Use `on`/`off`, `true`/`false`, or `ON`/`OFF`
- Case insensitive

## Examples

### Basic Dataset Creation
```bash
# Create a simple CSV file
cat > simple_datasets.csv << EOF
name,pool,comments
webapps,tank,Web applications
databases,tank,Database storage
backups,tank,Backup storage
EOF

# Create the datasets
./truenas_dataset_creator.sh simple_datasets.csv
```

### Advanced Configuration with Human-Readable Sizes
```bash
# Create datasets with human-readable sizes
cat > advanced_datasets.csv << EOF
name,pool,comments,compression,quota,recordsize,atime
mysql,tank,MySQL databases,lz4,100GB,8K,off
media,tank,Media streaming,lz4,5TB,1M,off
logs,tank,Application logs,gzip,50GB,128K,off
EOF

# Test first, then create
./truenas_dataset_creator.sh --dry-run advanced_datasets.csv
./truenas_dataset_creator.sh advanced_datasets.csv
```

### Encrypted Dataset Creation
```bash
# Create encrypted datasets with mixed configurations
cat > encrypted_datasets.csv << EOF
name,pool,comments,encryption,encryption_passphrase,quota
secure_docs,tank,Confidential documents,true,MyCompanySecret123,20GB
auto_backup,tank,Auto-encrypted backups,true,,100GB
public_files,tank,Public file storage,false,,50GB
financial,tank,Financial records,true,Finance2024!,10GB
EOF

# Preview encryption settings
./truenas_dataset_creator.sh --dry-run encrypted_datasets.csv

# Create encrypted datasets
./truenas_dataset_creator.sh encrypted_datasets.csv
```

### Child Dataset Creation
```bash
# Create hierarchical datasets (parents created automatically)
cat > hierarchical_datasets.csv << EOF
name,pool,comments,compression,recordsize
applications,tank,Application storage,lz4,128K
applications/web,tank,Web applications,lz4,128K
applications/web/nginx,tank,Nginx configuration,lz4,128K
applications/web/apache,tank,Apache configuration,lz4,128K
applications/api,tank,API services,lz4,128K
applications/api/v1,tank,API version 1,lz4,128K
applications/api/v2,tank,API version 2,lz4,128K
EOF

# The script will automatically:
# 1. Sort datasets by hierarchy (parents first)
# 2. Create parent datasets before children
# 3. Skip parents that already exist
./truenas_dataset_creator.sh hierarchical_datasets.csv
```

### Complete Example with All Features
```bash
# Create a comprehensive dataset configuration
cat > complete_example.csv << EOF
name,pool,comments,compression,quota,refquota,reservation,recordsize,encryption,encryption_passphrase
applications,tank,Application root,lz4,500GB,400GB,50GB,128K,false,
applications/web,tank,Web applications,lz4,100GB,80GB,10GB,128K,false,
applications/api,tank,API services,lz4,50GB,NONE,5GB,128K,true,WebAPISecret2024
secure,tank,Encrypted storage root,lz4,1TB,800GB,100GB,128K,true,SecureRoot123
secure/documents,tank,Confidential docs,lz4,200GB,NONE,20GB,128K,true,
secure/backups,tank,Secure backups,gzip,300GB,NONE,30GB,1M,true,
media,tank,Media files,lz4,10TB,NONE,1TB,1M,false,
media/movies,tank,Movie collection,lz4,5TB,NONE,500GB,1M,false,
media/music,tank,Music library,lz4,2TB,NONE,200GB,128K,false,
EOF

# Preview the complete configuration
./truenas_dataset_creator.sh --dry-run complete_example.csv

# Create all datasets
./truenas_dataset_creator.sh complete_example.csv
```

## Error Handling

The script includes comprehensive error handling:

- **Connection validation** - Tests API connectivity before proceeding
- **Pool validation** - Verifies target pools exist
- **Input validation** - Checks CSV format and required fields
- **Duplicate detection** - Can skip existing datasets
- **Detailed logging** - Clear success/error messages

### Common Issues

1. **API Connection Failed**
   ```
   [ERROR] Failed to connect to TrueNAS API (HTTP 401)
   ```
   - Check API key is correct
   - Verify TrueNAS host URL is accessible
   - Ensure API key has sufficient permissions

2. **Pool Does Not Exist**
   ```
   [ERROR] Pool 'mypool' does not exist
   ```
   - Verify pool name spelling in CSV
   - Check pool is imported and available

3. **CSV Format Error**
   ```
   [ERROR] CSV file must contain 'name' and 'pool' columns
   ```
   - Ensure CSV has proper headers
   - Check for missing required columns

## Security Considerations

- **Keep `config.env` secure** - Contains sensitive API credentials
- **Use HTTPS** - Always connect to TrueNAS over HTTPS
- **API Key Permissions** - Use least-privilege API keys
- **SSL Verification** - Keep `VERIFY_SSL="true"` in production
- **Version Control** - Add `config.env` to `.gitignore`

## Requirements

### System Requirements
- **Bash 4.0+** or **Zsh** (for shell scripting)
- **curl** (for TrueNAS API calls)
- **bc** (for human-readable size calculations)
- **Standard Unix tools** (grep, sed, cut, tr, etc.)

### Optional but Recommended
- **jq** (for pretty JSON formatting in dry-run mode)
  ```bash
  # Install on macOS
  brew install jq
  
  # Install on Ubuntu/Debian
  sudo apt-get install jq
  
  # Install on RHEL/CentOS
  sudo yum install jq
  ```

## Troubleshooting

### Enable Verbose Logging
```bash
./truenas_dataset_creator.sh -v datasets.csv
```

### Test Individual Components
```bash
# Test configuration
source config.env
curl -H "Authorization: Bearer $TRUENAS_API_KEY" \
     "$TRUENAS_HOST/api/v2.0/system/info"

# Test CSV parsing
head -5 datasets.csv
```

### Test Size Conversion
```bash
# Test human-readable size conversion
echo "Testing size conversion:"
echo "1GB should be 1073741824 bytes"
echo "500MB should be 524288000 bytes"

# Verify bc is available for calculations
bc --version
```

### Test Encryption Features
```bash
# Create a test encrypted dataset
cat > test_encryption.csv << EOF
name,pool,encryption,encryption_passphrase
test_encrypted,tank,true,TestPassword123
EOF

# Test in dry-run mode first
./truenas_dataset_creator.sh --dry-run test_encryption.csv
```

## What's New in This Version

### 🆕 Human-Readable Sizes
- **Before**: `quota,refquota,reservation,refreservation` required exact bytes
- **Now**: Use intuitive formats like `10GB`, `500MB`, `2.5TB`
- **Benefits**: Much easier to read and write CSV files
- **Backward compatible**: Raw bytes still work

### 🔐 Dataset Encryption Support
- **New feature**: Create encrypted datasets directly from CSV
- **Two modes**: Passphrase-based or auto-generated keys
- **Secure defaults**: AES-256-GCM encryption algorithm
- **Easy to use**: Just add `encryption=true` to your CSV

### 🗑️ Bulk Deletion Tool
- **New script**: `truenas_dataset_deleter.sh` for cleanup
- **Safety features**: Dry-run mode, confirmation prompts
- **Flexible targeting**: Delete by pool or pattern
- **Smart ordering**: Deletes children before parents

### ⚡ Performance Improvements
- **Fixed counters**: Summary statistics now work correctly
- **Better error reporting**: More detailed API error messages
- **Verbose logging**: Enhanced debugging with `-v` flag
- **Robust parsing**: Improved CSV handling and validation

### 🛠️ Enhanced Usability
- **Updated help text**: Comprehensive documentation in `--help`
- **Better examples**: Real-world CSV templates
- **Improved validation**: Better error messages for common issues
- **Cleaner output**: Color-coded status messages

## Contributing

To extend or modify the scripts:

1. **Add new dataset properties** - Update the `build_dataset_config` function
2. **Add new size conversion logic** - Extend the `convert_size_to_bytes` function
3. **Add validation rules** - Extend the `validate_csv_file` function
4. **Improve error handling** - Add more specific error cases
5. **Add new encryption options** - Enhance the encryption handling logic

## License

This project is provided as-is for automation purposes. Use at your own risk and always test in a non-production environment first.

---

**⚠️ Important**: Always run `--dry-run` first to preview operations before creating datasets on your production TrueNAS system!