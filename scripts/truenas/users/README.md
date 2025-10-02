# TrueNAS Scale User Management

This directory contains scripts for managing TrueNAS Scale users via the REST API. The scripts provide functionality for creating, managing, and deleting user accounts through CSV-based bulk operations, with support for importing from Excel spreadsheets.

## Overview

The TrueNAS user management automation provides:

- **Bulk User Creation**: Create multiple users from CSV or Excel files
- **User Deletion**: Remove users with safety confirmations
- **Excel Integration**: Convert Excel spreadsheets to CSV format
- **Comprehensive Validation**: Input validation and error handling
- **Dry Run Mode**: Preview changes before execution
- **Group Management**: Assign users to primary and secondary groups

## Quick Start

### Prerequisites

- TrueNAS Scale system with API access enabled
- API key generated in TrueNAS (System Settings > General > API Keys)
- `curl` command available on your system
- `python3` with `pandas` and `openpyxl` libraries (for Excel support)
- `bash` shell (version 4.0 or later recommended)

### Basic Workflow

1. **Generate API Key** in TrueNAS UI (System Settings > General > API Keys)
2. **Copy configuration template**: `cp config.env.template config.env`
3. **Edit configuration** with your TrueNAS details
4. **Create CSV file** with user definitions (or convert from Excel)
5. **Run dry-run** to preview changes: `./truenas_user_creator.sh --dry-run users.csv`
6. **Execute script** to create users: `./truenas_user_creator.sh users.csv`

## Files Overview

```
users/
├── README.md                    # This documentation file
├── config.env.template          # Configuration template
├── truenas_user_creator.sh      # Create users from CSV/Excel
├── truenas_user_deleter.sh      # Delete users with confirmations
├── excel_to_csv.py              # Convert Excel to CSV format
├── example_users.csv            # Example user definitions
├── example_bulk_users.csv       # Bulk user example with variations
└── example_delete_users.csv     # Example deletion CSV
```

## Configuration

Create a `config.env` file from the template:

```bash
cp config.env.template config.env
```

Edit the configuration with your TrueNAS details:

```bash
# TrueNAS server URL (include https:// or http://)
TRUENAS_HOST="https://192.168.1.100"

# TrueNAS API Key (generate in System Settings > General > API Keys)
TRUENAS_API_KEY="your-api-key-here"

# SSL Certificate Verification (set to "false" for self-signed certificates)
VERIFY_SSL="true"

# Default settings for user creation
DEFAULT_SHELL="/usr/bin/bash"
DEFAULT_HOME_PREFIX="/mnt/tank/home"
DEFAULT_PASSWORD_DISABLED="false"
```

## CSV Format

### Required Columns

| Column | Description | Example |
|--------|-------------|---------|
| `username` | Unique username for login | `jdoe` |
| `full_name` | User's full display name | `John Doe` |

### Optional Columns

| Column | Description | Default | Example |
|--------|-------------|---------|---------|
| `password` | User password (plain text) | Generated | `SecurePass123!` |
| `email` | Email address | Empty | `jdoe@company.com` |
| `uid` | User ID number | Auto-assigned | `1001` |
| `primary_group` | Primary group name | `users` | `staff` |
| `secondary_groups` | Comma-separated group list | Empty | `sudo,docker,media` |
| `home_directory` | Full path to home directory | `/mnt/tank/home/{username}` | `/mnt/tank/home/jdoe` |
| `shell` | Login shell | `/usr/bin/bash` | `/bin/zsh` |
| `locked` | Account locked status | `false` | `true` |
| `password_disabled` | Disable password login | `false` | `true` |
| `sudo_enabled` | Grant sudo access | `false` | `true` |
| `ssh_public_key` | SSH public key | Empty | `ssh-rsa AAAAB3...` |
| `quota` | Home directory quota | Unlimited | `10GB` |
| `comments` | Additional notes | Empty | `Department manager` |

### CSV Examples

#### Basic Users
```csv
username,full_name,email,primary_group
jdoe,John Doe,jdoe@company.com,users
jane.smith,Jane Smith,jane.smith@company.com,staff
admin.user,Admin User,admin@company.com,wheel
```

#### Advanced Users with Custom Settings
```csv
username,full_name,password,uid,primary_group,secondary_groups,shell,sudo_enabled,quota,comments
developer1,Dev User One,TempPass123,1500,developers,"docker,sudo",/bin/zsh,true,50GB,Senior Developer
dbadmin,Database Admin,SecureDB456,1501,dba,"sudo,backup",/usr/bin/bash,true,20GB,Database Administrator
mediauser,Media User,MediaPass789,1502,media,"plex,jellyfin",/usr/bin/bash,false,2TB,Media Server User
```

## Script Usage

### User Creation Script

```bash
# Basic usage
./truenas_user_creator.sh users.csv

# Preview changes without creating users
./truenas_user_creator.sh --dry-run users.csv

# Skip users that already exist
./truenas_user_creator.sh --skip-existing users.csv

# Use custom configuration file
./truenas_user_creator.sh -c prod_config.env users.csv

# Enable verbose logging
./truenas_user_creator.sh -v users.csv

# Generate passwords and save to file
./truenas_user_creator.sh --generate-passwords --password-file passwords.txt users.csv
```

#### User Creation Options

| Option | Description |
|--------|-------------|
| `-c, --config FILE` | Specify configuration file (default: config.env) |
| `--dry-run` | Preview changes without creating users |
| `--skip-existing` | Skip users that already exist |
| `--generate-passwords` | Auto-generate passwords for users without them |
| `--password-file FILE` | Save generated passwords to specified file |
| `--create-home-dirs` | Automatically create home directories |
| `-v, --verbose` | Enable detailed logging |
| `-h, --help` | Show help message |

### User Deletion Script

```bash
# Delete users from CSV file
./truenas_user_deleter.sh users_to_delete.csv

# Force deletion without confirmation
./truenas_user_deleter.sh --force users_to_delete.csv

# Delete single user
./truenas_user_deleter.sh --username "olduser"

# List all users
./truenas_user_deleter.sh --list

# Delete user and preserve home directory
./truenas_user_deleter.sh --preserve-home users_to_delete.csv
```

#### User Deletion Options

| Option | Description |
|--------|-------------|
| `-c, --config FILE` | Specify configuration file |
| `--force` | Skip confirmation prompts |
| `--username USER` | Delete single user by username |
| `--preserve-home` | Keep home directories when deleting users |
| `--list` | List all existing users |
| `-v, --verbose` | Enable detailed logging |
| `-h, --help` | Show help message |

## Excel Integration

### Converting Excel to CSV

Use the provided Python script to convert Excel files:

```bash
# Convert Excel file to CSV
python3 excel_to_csv.py users.xlsx

# Specify output file
python3 excel_to_csv.py users.xlsx --output converted_users.csv

# Convert specific sheet
python3 excel_to_csv.py users.xlsx --sheet "Employee List"

# Preview conversion without saving
python3 excel_to_csv.py users.xlsx --dry-run
```

### Excel File Requirements

- **Header Row**: First row must contain column names matching CSV format
- **Sheet Selection**: Script can handle multiple sheets
- **Data Validation**: Empty rows are automatically skipped
- **Format Support**: Supports .xlsx, .xls formats

### Example Excel Structure

| A | B | C | D | E |
|---|---|---|---|---|
| username | full_name | email | primary_group | secondary_groups |
| jdoe | John Doe | jdoe@company.com | users | sudo,docker |
| jane.smith | Jane Smith | jane@company.com | staff | media |

## Advanced Features

### Password Management

#### Auto-Generated Passwords
```bash
# Generate secure passwords for all users
./truenas_user_creator.sh --generate-passwords --password-file generated_passwords.txt users.csv
```

#### Password Requirements
- Minimum 8 characters
- Mix of letters, numbers, and symbols
- Automatically saved to secure file with restricted permissions

### Group Management

#### Creating Required Groups
The script can automatically create missing groups:
```bash
./truenas_user_creator.sh --create-groups users.csv
```

#### Group Assignment
- **Primary Group**: User's default group for file ownership
- **Secondary Groups**: Additional groups for permissions
- **Special Groups**: `wheel`, `sudo` for administrative access

### Home Directory Management

#### Automatic Creation
```bash
# Create home directories with proper ownership
./truenas_user_creator.sh --create-home-dirs users.csv
```

#### Custom Home Paths
Set custom home directory patterns in CSV:
```csv
username,full_name,home_directory
projectuser,Project User,/mnt/tank/projects/projectuser
```

#### Quotas
Set storage quotas for user home directories:
```csv
username,full_name,quota
poweruser,Power User,100GB
basicuser,Basic User,10GB
```

## Security Considerations

### Best Practices

1. **Password Security**
   - Use strong, unique passwords
   - Store generated passwords securely
   - Require password changes on first login
   - Consider SSH key authentication

2. **Group Management**
   - Follow principle of least privilege
   - Regularly audit group memberships
   - Use dedicated groups for specific access

3. **Home Directory Security**
   - Set appropriate permissions (750 or 755)
   - Use quotas to prevent disk exhaustion
   - Regular backup of user data

### API Security

```bash
# Secure configuration file permissions
chmod 600 config.env

# Use dedicated API key for user management
# Rotate API keys regularly
# Monitor API usage logs
```

## Troubleshooting

### Common Issues

#### 1. Authentication Failures
```
Error: HTTP 401 - Authentication failed
```
**Solutions:**
- Verify API key is correct and not expired
- Check TrueNAS user has admin privileges
- Ensure API key is properly formatted

#### 2. Group Not Found
```
Error: Primary group 'developers' does not exist
```
**Solutions:**
- Create group first: `./truenas_group_creator.sh groups.csv`
- Use `--create-groups` option
- Verify group name spelling

#### 3. Username Conflicts
```
Error: User 'jdoe' already exists
```
**Solutions:**
- Use `--skip-existing` to skip duplicates
- Check existing users: `./truenas_user_deleter.sh --list`
- Choose unique usernames

#### 4. Home Directory Issues
```
Error: Cannot create home directory /mnt/tank/home/user
```
**Solutions:**
- Verify parent directory exists
- Check filesystem permissions
- Ensure sufficient disk space
- Use `--create-home-dirs` option

### Debug Mode

Enable verbose logging for detailed troubleshooting:
```bash
./truenas_user_creator.sh -v users.csv
./truenas_user_deleter.sh -v users_to_delete.csv
```

### Log Files

Scripts create detailed logs in:
```
logs/
├── user_creation_YYYYMMDD_HHMMSS.log
├── user_deletion_YYYYMMDD_HHMMSS.log
└── api_calls_YYYYMMDD_HHMMSS.log
```

## Workflow Examples

### Complete User Onboarding
```bash
# 1. Convert Excel file from HR
python3 excel_to_csv.py new_employees.xlsx

# 2. Preview user creation
./truenas_user_creator.sh --dry-run new_employees.csv

# 3. Create groups if needed
./truenas_group_creator.sh --dry-run groups.csv
./truenas_group_creator.sh groups.csv

# 4. Create users with home directories
./truenas_user_creator.sh --create-home-dirs --generate-passwords --password-file passwords.txt new_employees.csv

# 5. Email passwords to users (manual step)
# 6. Set up shared directories and permissions
```

### User Offboarding
```bash
# 1. List current users
./truenas_user_deleter.sh --list

# 2. Create deletion CSV
echo "username" > departing_users.csv
echo "oldemployee" >> departing_users.csv

# 3. Backup user data (manual step)
# 4. Delete users but preserve home directories
./truenas_user_deleter.sh --preserve-home departing_users.csv

# 5. Archive home directories (manual step)
```

### Bulk User Management
```bash
# Update user information
./truenas_user_updater.sh updated_users.csv

# Reset passwords for security
./truenas_user_creator.sh --generate-passwords --password-file new_passwords.txt --update-existing users.csv

# Bulk group changes
./truenas_user_creator.sh --update-groups group_changes.csv
```

## Integration Examples

### CI/CD Pipeline
```yaml
# Example GitHub Actions workflow
name: User Management
on:
  push:
    paths:
      - 'users/*.csv'
      
jobs:
  update-users:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v2
      - name: Update TrueNAS Users
        run: |
          cd scripts/truenas/users
          ./truenas_user_creator.sh --skip-existing users.csv
```

### Monitoring Integration
```bash
# Check for script success/failure
if ./truenas_user_creator.sh users.csv; then
    echo "SUCCESS: Users created successfully" | logger
else
    echo "ERROR: User creation failed" | logger -p user.error
    # Send alert notification
fi
```

## API Endpoints Used

These scripts interact with the following TrueNAS Scale REST API v2.0 endpoints:

- **System Info**: `GET /api/v2.0/system/info`
- **Users**: `GET/POST/PUT/DELETE /api/v2.0/user`
- **Groups**: `GET /api/v2.0/group`
- **Filesystem**: `POST /api/v2.0/filesystem/mkdir` (for home directories)

## Contributing

When contributing to user management scripts:

1. **Follow security best practices**: Never log or expose passwords
2. **Test with non-production data**: Use test TrueNAS instances
3. **Maintain compatibility**: Ensure changes work with existing CSV formats
4. **Document changes**: Update README and help text
5. **Handle errors gracefully**: Provide clear error messages and recovery steps

## Limitations

- **Bulk Operations**: Large user imports may take time due to API rate limits
- **Password Complexity**: Password policies are enforced by TrueNAS
- **Group Dependencies**: Groups must exist before assigning to users
- **Home Directory Permissions**: May require manual adjustment for specific use cases
- **SSH Key Format**: Only supports standard SSH public key formats

---

**Note**: These scripts are designed for TrueNAS Scale and may require modifications for TrueNAS Core (FreeBSD-based) systems.