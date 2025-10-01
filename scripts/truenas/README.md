# TrueNAS Scale Dataset Creator

A set of shell scripts to automate the creation of ZFS datasets on TrueNAS Scale using the REST API. This tool allows you to define datasets in an Excel file and create them in bulk.

## Features

- ✅ **Bulk dataset creation** from Excel/CSV input files
- ✅ **Child dataset support** with automatic parent creation
- ✅ **Hierarchical processing** ensures parents are created before children
- ✅ **Excel to CSV conversion** for easy input preparation
- ✅ **Comprehensive dataset configuration** support
- ✅ **Dry run mode** to preview operations
- ✅ **Skip existing datasets** option
- ✅ **Pool validation** to ensure target pools exist
- ✅ **Detailed logging** with colored output
- ✅ **Error handling** and recovery
- ✅ **Secure configuration** management

## Files Overview

```
truenasv2/
├── truenas_dataset_creator.sh  # Main script for dataset creation
├── excel_to_csv.sh             # Helper script for Excel conversion
├── config.env.template         # Configuration template
├── example_datasets.csv        # Example CSV input format
└── README.md                   # This documentation
```

## Quick Start

1. **Configure your TrueNAS connection**:
   ```bash
   cp config.env.template config.env
   # Edit config.env with your TrueNAS details
   ```

2. **Prepare your dataset definitions** (choose one):
   
   **Option A: Use CSV directly**
   ```bash
   # Copy and modify the example
   cp example_datasets.csv my_datasets.csv
   ```
   
   **Option B: Convert from Excel**
   ```bash
   # Convert your Excel file to CSV
   ./excel_to_csv.sh my_datasets.xlsx
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
- `comments` - Description/comments for the dataset
- `compression` - Compression algorithm (lz4, gzip, zstd, etc.)
- `deduplication` - Deduplication setting (on/off)
- `quota` - Dataset quota in bytes (or NONE)
- `refquota` - Reference quota in bytes (or NONE)
- `reservation` - Space reservation in bytes (or NONE)
- `refreservation` - Reference reservation in bytes (or NONE)
- `recordsize` - Record size (4K, 8K, 128K, 1M, etc.)
- `case_sensitivity` - Case sensitivity (sensitive/insensitive)
- `atime` - Access time updates (on/off)
- `exec` - Execute permissions (on/off)

#### Example CSV Format
```csv
name,pool,comments,compression,quota,recordsize
applications,tank,App storage,lz4,NONE,128K
applications/web,tank,Web apps,lz4,NONE,128K
applications/web/nginx,tank,Nginx config,lz4,NONE,128K
backup,tank,Backup data,gzip,500000000000,1M
backup/daily,tank,Daily backups,gzip,NONE,1M
media,tank,Media files,lz4,NONE,1M
media/movies,tank,Movie collection,lz4,NONE,1M
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

### Excel to CSV Converter

```bash
./excel_to_csv.sh <excel_file> [output_file]
```

#### Examples
```bash
# Convert to default name (datasets.csv)
./excel_to_csv.sh datasets.xlsx

# Convert to specific output file
./excel_to_csv.sh datasets.xlsx my_datasets.csv
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
- Use byte values: `1000000000` (1GB), `500000000000` (500GB)
- Use `NONE` for no quota/reservation
- Reservations guarantee space availability

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

### Advanced Configuration
```bash
# Create datasets with specific settings
cat > advanced_datasets.csv << EOF
name,pool,comments,compression,quota,recordsize,atime
mysql,tank,MySQL databases,lz4,100000000000,8K,off
media,tank,Media streaming,lz4,NONE,1M,off
logs,tank,Application logs,gzip,50000000000,128K,off
EOF

# Test first, then create
./truenas_dataset_creator.sh --dry-run advanced_datasets.csv
./truenas_dataset_creator.sh advanced_datasets.csv
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

### Working with Excel Files
```bash
# Convert Excel to CSV
./excel_to_csv.sh company_datasets.xlsx

# Preview the conversion
head -5 company_datasets.csv

# Create datasets with verbose output
./truenas_dataset_creator.sh -v company_datasets.csv
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
- Bash 4.0+ or Zsh
- curl (for API calls)
- Standard Unix tools (grep, sed, cut, etc.)

### For Excel Conversion
- Python 3.x
- pandas package: `pip install pandas`
- openpyxl package: `pip install openpyxl`

### Optional
- jq (for pretty JSON formatting in dry-run mode)

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

### Validate Excel Conversion
```bash
# Check Python requirements
python3 -c "import pandas, openpyxl; print('OK')"

# Manual conversion test
python3 -c "import pandas as pd; print(pd.read_excel('file.xlsx').head())"
```

## Contributing

To extend or modify the scripts:

1. **Add new dataset properties** - Update the `build_dataset_config` function
2. **Support new input formats** - Create additional converter scripts
3. **Add validation rules** - Extend the `validate_csv_file` function
4. **Improve error handling** - Add more specific error cases

## License

This project is provided as-is for automation purposes. Use at your own risk and always test in a non-production environment first.

---

**⚠️ Important**: Always run `--dry-run` first to preview operations before creating datasets on your production TrueNAS system!