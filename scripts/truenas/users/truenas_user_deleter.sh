#!/bin/bash
#
# TrueNAS Scale User Deleter
#
# This script deletes users from TrueNAS Scale using the REST API.
# It supports CSV input, individual user deletion, and safety features
# including confirmation prompts and home directory preservation.
#
# Usage: ./truenas_user_deleter.sh [OPTIONS] [csv_file]
#
# Author: Generated for TrueNAS automation
#

set -euo pipefail

# Default values
CONFIG_FILE="config.env"
FORCE=false
VERBOSE=false
LIST_USERS=false
USERNAME=""
PRESERVE_HOME=false
BACKUP_BEFORE_DELETE=false
CSV_FILE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Global counters
TOTAL_USERS=0
DELETED_USERS=0
SKIPPED_USERS=0
FAILED_USERS=0

# Arrays for tracking
DELETED_USER_LIST=()
FAILED_USER_LIST=()

# Function to print colored output
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [csv_file]
   or: $0 --username <username> [OPTIONS]
   or: $0 --list [OPTIONS]

Delete TrueNAS users from CSV file, individual user, or list all users

OPTIONS:
    -c, --config FILE       Configuration file (default: config.env)
    --force                 Skip confirmation prompts
    --username USER         Delete a single user by username
    --preserve-home         Keep home directories when deleting users
    --backup-before-delete  Backup user data before deletion
    --list                  List all existing users
    -v, --verbose           Enable verbose logging
    -h, --help              Show this help message

ARGUMENTS:
    csv_file                Path to CSV file containing usernames to delete

EXAMPLES:
    # List all users
    $0 --list
    
    # Delete users from CSV file
    $0 users_to_delete.csv
    
    # Delete single user with confirmation
    $0 --username "olduser"
    
    # Force delete without confirmation, preserving home
    $0 --force --preserve-home users_to_delete.csv
    
    # Backup user data before deletion
    $0 --backup-before-delete users_to_delete.csv

CSV FORMAT:
    Single column with header 'username':
    
    username
    user1
    user2
    olduser

SAFETY FEATURES:
    - Confirmation prompts (unless --force is used)
    - Home directory preservation option
    - User data backup option
    - Cannot delete system users (UID < 1000 by default)
    - Detailed logging and error reporting

EOF
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --username)
                USERNAME="$2"
                shift 2
                ;;
            --preserve-home)
                PRESERVE_HOME=true
                shift
                ;;
            --backup-before-delete)
                BACKUP_BEFORE_DELETE=true
                shift
                ;;
            --list)
                LIST_USERS=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$CSV_FILE" ] && [ -z "$USERNAME" ] && [ "$LIST_USERS" = false ]; then
                    CSV_FILE="$1"
                else
                    log_error "Multiple input methods specified"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Validate arguments
    if [ -z "$CSV_FILE" ] && [ -z "$USERNAME" ] && [ "$LIST_USERS" = false ]; then
        log_error "Must specify CSV file, username, or --list option"
        show_usage
        exit 1
    fi

    if [ -n "$CSV_FILE" ] && [ -n "$USERNAME" ]; then
        log_error "Cannot specify both CSV file and username"
        exit 1
    fi

    if [ "$LIST_USERS" = true ] && ([ -n "$CSV_FILE" ] || [ -n "$USERNAME" ]); then
        log_error "Cannot combine --list with other input methods"
        exit 1
    fi
}

# Function to load configuration
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        log_info "Please create a configuration file with the following format:"
        cat << EOF

# TrueNAS connection settings
TRUENAS_HOST="https://your-truenas-ip-or-hostname"
TRUENAS_API_KEY="your-api-key-here"
VERIFY_SSL="true"

EOF
        exit 1
    fi

    log_debug "Loading configuration from: $CONFIG_FILE"
    source "$CONFIG_FILE"

    # Validate required configuration
    if [ -z "${TRUENAS_HOST:-}" ] || [ -z "${TRUENAS_API_KEY:-}" ]; then
        log_error "Missing required configuration: TRUENAS_HOST and TRUENAS_API_KEY must be set"
        exit 1
    fi

    # Set defaults for optional configuration
    VERIFY_SSL="${VERIFY_SSL:-true}"
    API_TIMEOUT="${API_TIMEOUT:-30}"
    MIN_USER_UID="${MIN_USER_UID:-1000}"
    BACKUP_DIRECTORY="${BACKUP_DIRECTORY:-/mnt/tank/backups/user-data}"
    BACKUP_COMPRESSION="${BACKUP_COMPRESSION:-gzip}"
    CLEANUP_EMPTY_HOME_DIRS="${CLEANUP_EMPTY_HOME_DIRS:-true}"
}

# Function to make API calls to TrueNAS
truenas_api_call() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    local curl_opts=()

    # Build curl options
    curl_opts+=(-s -w "%{http_code}")
    curl_opts+=(-H "Authorization: Bearer $TRUENAS_API_KEY")
    curl_opts+=(-H "Content-Type: application/json")
    curl_opts+=(--max-time "$API_TIMEOUT")

    if [ "$VERIFY_SSL" != "true" ]; then
        curl_opts+=(-k)
    fi

    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        curl_opts+=(-X POST -d "$data")
    elif [ "$method" = "PUT" ] && [ -n "$data" ]; then
        curl_opts+=(-X PUT -d "$data")
    elif [ "$method" = "DELETE" ]; then
        curl_opts+=(-X DELETE)
    fi

    log_debug "API Call: $method ${TRUENAS_HOST}/api/v2.0${endpoint}"
    if [ -n "$data" ] && [ "${DEBUG_API_CALLS:-false}" = "true" ]; then
        log_debug "Payload: $data"
    fi

    local response
    response=$(curl "${curl_opts[@]}" "${TRUENAS_HOST}/api/v2.0${endpoint}" 2>/dev/null)
    
    local http_code="${response: -3}"
    local response_body="${response%???}"
    
    log_debug "Response Code: $http_code"
    if [ "${DEBUG_API_CALLS:-false}" = "true" ]; then
        log_debug "Response Body: $response_body"
    fi
    
    echo "$http_code|$response_body"
}

# Function to test TrueNAS API connectivity
test_connection() {
    log_info "Testing connection to TrueNAS: $TRUENAS_HOST"
    
    local result
    result=$(truenas_api_call "GET" "/system/info")
    local http_code="${result%%|*}"
    local response_body="${result##*|}"
    
    if [ "$http_code" = "200" ]; then
        local hostname
        hostname=$(echo "$response_body" | grep -o '"hostname":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "unknown")
        log_success "Successfully connected to TrueNAS (hostname: $hostname)"
        return 0
    else
        log_error "Failed to connect to TrueNAS API (HTTP $http_code)"
        if [ "$http_code" = "401" ]; then
            log_error "Authentication failed - check your API key"
        elif [ "$http_code" = "000" ]; then
            log_error "Connection failed - check host URL and network connectivity"
        fi
        return 1
    fi
}

# Function to get user information
get_user_info() {
    local username="$1"
    
    local result
    result=$(truenas_api_call "GET" "/user?username=$username")
    local http_code="${result%%|*}"
    local response_body="${result##*|}"
    
    if [ "$http_code" = "200" ]; then
        echo "$response_body"
        return 0
    else
        return 1
    fi
}

# Function to list all users
list_all_users() {
    log_info "Retrieving list of all users..."
    
    local result
    result=$(truenas_api_call "GET" "/user")
    local http_code="${result%%|*}"
    local response_body="${result##*|}"
    
    if [ "$http_code" = "200" ]; then
        echo ""
        log_info "All TrueNAS Users:"
        log_info "=================="
        
        # Parse JSON response and display user information
        echo "$response_body" | grep -o '"username":"[^"]*","full_name":"[^"]*","uid":[^,]*,"home":"[^"]*"' | while IFS= read -r line; do
            local username=$(echo "$line" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
            local full_name=$(echo "$line" | grep -o '"full_name":"[^"]*"' | cut -d'"' -f4)
            local uid=$(echo "$line" | grep -o '"uid":[^,]*' | cut -d':' -f2)
            local home=$(echo "$line" | grep -o '"home":"[^"]*"' | cut -d'"' -f4)
            
            printf "%-20s %-30s UID: %-6s Home: %s\n" "$username" "$full_name" "$uid" "$home"
        done
        
        echo ""
        local user_count
        user_count=$(echo "$response_body" | grep -o '"username":"[^"]*"' | wc -l)
        log_info "Total users: $user_count"
        
    else
        log_error "Failed to retrieve user list (HTTP $http_code)"
        return 1
    fi
}

# Function to validate CSV file
validate_csv() {
    local csv_file="$1"
    
    if [ ! -f "$csv_file" ]; then
        log_error "CSV file not found: $csv_file"
        return 1
    fi
    
    if [ ! -r "$csv_file" ]; then
        log_error "Cannot read CSV file: $csv_file"
        return 1
    fi
    
    # Check if file is empty
    if [ ! -s "$csv_file" ]; then
        log_error "CSV file is empty: $csv_file"
        return 1
    fi
    
    # Read header line
    local header
    header=$(head -n1 "$csv_file")
    
    # Check for required column
    if [[ ! "$header" =~ username ]]; then
        log_error "CSV file missing required column: username"
        log_info "Found columns: $header"
        return 1
    fi
    
    # Count data lines (excluding header)
    local line_count
    line_count=$(tail -n +2 "$csv_file" | grep -c "^[^[:space:]]*" || true)
    
    if [ "$line_count" -eq 0 ]; then
        log_warning "No user data found in CSV file"
        return 1
    fi
    
    TOTAL_USERS=$line_count
    log_info "CSV validation successful: $TOTAL_USERS users found for deletion"
    return 0
}

# Function to check if user is a system user
is_system_user() {
    local username="$1"
    
    local user_info
    user_info=$(get_user_info "$username")
    
    if [ -n "$user_info" ]; then
        local uid
        uid=$(echo "$user_info" | grep -o '"uid":[^,]*' | cut -d':' -f2)
        
        if [ "$uid" -lt "$MIN_USER_UID" ]; then
            return 0  # Is system user
        fi
    fi
    
    return 1  # Not system user or user not found
}

# Function to backup user data
backup_user_data() {
    local username="$1"
    local home_dir="$2"
    
    log_info "Backing up data for user: $username"
    
    # Create backup directory if it doesn't exist
    if [ ! -d "$BACKUP_DIRECTORY" ]; then
        log_info "Creating backup directory: $BACKUP_DIRECTORY"
        mkdir -p "$BACKUP_DIRECTORY" || {
            log_error "Failed to create backup directory"
            return 1
        }
    fi
    
    # Generate backup filename with timestamp
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_filename="${username}_${timestamp}"
    
    case "$BACKUP_COMPRESSION" in
        "gzip")
            backup_filename="${backup_filename}.tar.gz"
            local tar_opts="czf"
            ;;
        "bzip2")
            backup_filename="${backup_filename}.tar.bz2"
            local tar_opts="cjf"
            ;;
        *)
            backup_filename="${backup_filename}.tar"
            local tar_opts="cf"
            ;;
    esac
    
    local backup_path="$BACKUP_DIRECTORY/$backup_filename"
    
    # Check if home directory exists and has content
    if [ ! -d "$home_dir" ]; then
        log_warning "Home directory not found: $home_dir (skipping backup)"
        return 0
    fi
    
    # Create backup using tar
    log_info "Creating backup: $backup_path"
    if tar $tar_opts "$backup_path" -C "$(dirname "$home_dir")" "$(basename "$home_dir")" 2>/dev/null; then
        local backup_size=$(du -h "$backup_path" | cut -f1)
        log_success "Backup created successfully: $backup_path ($backup_size)"
        return 0
    else
        log_error "Failed to create backup for user: $username"
        return 1
    fi
}

# Function to delete home directory
delete_home_directory() {
    local username="$1"
    local home_dir="$2"
    
    if [ "$PRESERVE_HOME" = true ]; then
        log_info "Preserving home directory: $home_dir"
        return 0
    fi
    
    log_info "Removing home directory: $home_dir"
    
    # Check if directory exists
    if [ ! -d "$home_dir" ]; then
        log_debug "Home directory does not exist: $home_dir"
        return 0
    fi
    
    # Remove directory via filesystem API if available, otherwise skip
    # TrueNAS will typically handle home directory cleanup automatically
    log_debug "Home directory cleanup will be handled by TrueNAS"
    
    return 0
}

# Function to confirm deletion
confirm_deletion() {
    local username="$1"
    
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    echo ""
    log_warning "You are about to delete the user: $username"
    
    # Get user info for confirmation
    local user_info
    user_info=$(get_user_info "$username")
    if [ -n "$user_info" ]; then
        local full_name=$(echo "$user_info" | grep -o '"full_name":"[^"]*"' | cut -d'"' -f4)
        local uid=$(echo "$user_info" | grep -o '"uid":[^,]*' | cut -d':' -f2)
        local home=$(echo "$user_info" | grep -o '"home":"[^"]*"' | cut -d'"' -f4)
        
        echo "  Full Name: $full_name"
        echo "  UID: $uid"
        echo "  Home: $home"
        
        if [ "$PRESERVE_HOME" = false ]; then
            log_warning "Home directory will be deleted!"
        else
            log_info "Home directory will be preserved"
        fi
    fi
    
    echo ""
    read -p "Are you sure you want to delete this user? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deletion cancelled by user"
        return 1
    fi
    
    return 0
}

# Function to delete a user
delete_user() {
    local username="$1"
    
    log_info "Processing user deletion: $username"
    
    # Check if user exists and get info
    local user_info
    user_info=$(get_user_info "$username")
    if [ -z "$user_info" ]; then
        log_error "User not found: $username"
        ((FAILED_USERS++))
        FAILED_USER_LIST+=("$username")
        return 1
    fi
    
    # Check if it's a system user
    if is_system_user "$username"; then
        log_error "Cannot delete system user: $username (UID < $MIN_USER_UID)"
        ((FAILED_USERS++))
        FAILED_USER_LIST+=("$username")
        return 1
    fi
    
    # Get user details
    local full_name=$(echo "$user_info" | grep -o '"full_name":"[^"]*"' | cut -d'"' -f4)
    local uid=$(echo "$user_info" | grep -o '"uid":[^,]*' | cut -d':' -f2)
    local home=$(echo "$user_info" | grep -o '"home":"[^"]*"' | cut -d'"' -f4)
    
    # Confirm deletion
    if ! confirm_deletion "$username"; then
        log_info "Skipping user deletion: $username"
        ((SKIPPED_USERS++))
        return 0
    fi
    
    # Backup user data if requested
    if [ "$BACKUP_BEFORE_DELETE" = true ]; then
        backup_user_data "$username" "$home" || {
            log_warning "Backup failed, but continuing with deletion"
        }
    fi
    
    # Delete user via API
    log_info "Deleting user: $username"
    
    # Build deletion payload
    local payload=$(cat <<EOF
{
    "delete_group": false,
    "delete_home_directory": $([ "$PRESERVE_HOME" = false ] && echo "true" || echo "false")
}
EOF
    )
    
    local result
    result=$(truenas_api_call "DELETE" "/user/id/$uid" "$payload")
    local http_code="${result%%|*}"
    local response_body="${result##*|}"
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
        log_success "User deleted successfully: $username"
        ((DELETED_USERS++))
        DELETED_USER_LIST+=("$username")
        
        # Handle home directory if preservation is requested
        if [ "$PRESERVE_HOME" = true ]; then
            log_info "Home directory preserved at: $home"
        fi
        
        return 0
    else
        log_error "Failed to delete user $username (HTTP $http_code)"
        log_debug "Response: $response_body"
        ((FAILED_USERS++))
        FAILED_USER_LIST+=("$username")
        return 1
    fi
}

# Function to process CSV file
process_csv() {
    local csv_file="$1"
    
    log_info "Processing user deletions from: $csv_file"
    echo ""
    
    local line_num=1
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip header line
        if [ $line_num -eq 2 ]; then
            continue
        fi
        
        # Remove carriage returns and leading/trailing whitespace
        line=$(echo "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Skip empty lines
        if [ -z "$line" ]; then
            continue
        fi
        
        # Extract username (first column)
        local username=$(echo "$line" | cut -d',' -f1 | sed 's/^"//;s/"$//')
        
        # Validate username
        if [ -z "$username" ]; then
            log_error "Line $line_num: Empty username"
            continue
        fi
        
        delete_user "$username"
        echo ""
        
    done < "$csv_file"
}

# Function to print summary
print_summary() {
    echo ""
    log_info "=========================="
    log_info "User Deletion Summary"
    log_info "=========================="
    
    if [ -n "$CSV_FILE" ]; then
        log_info "Total users processed: $TOTAL_USERS"
    fi
    
    log_info "Successfully deleted: $DELETED_USERS"
    log_info "Skipped: $SKIPPED_USERS"
    log_info "Failed: $FAILED_USERS"
    
    if [ ${#DELETED_USER_LIST[@]} -gt 0 ]; then
        echo ""
        log_success "Successfully deleted users:"
        for user in "${DELETED_USER_LIST[@]}"; do
            echo "  - $user"
        done
    fi
    
    if [ ${#FAILED_USER_LIST[@]} -gt 0 ]; then
        echo ""
        log_error "Failed to delete users:"
        for user in "${FAILED_USER_LIST[@]}"; do
            echo "  - $user"
        done
    fi
    
    echo ""
    if [ "$FAILED_USERS" -eq 0 ] && [ "$DELETED_USERS" -gt 0 ]; then
        log_success "All requested users deleted successfully!"
        exit 0
    elif [ "$DELETED_USERS" -eq 0 ] && [ "$SKIPPED_USERS" -eq 0 ]; then
        log_warning "No users were deleted"
        exit 1
    else
        if [ "$FAILED_USERS" -gt 0 ]; then
            log_warning "Some users failed to be deleted. Check the logs above for details."
            exit 1
        else
            log_success "User deletion completed!"
            exit 0
        fi
    fi
}

# Main function
main() {
    echo ""
    log_info "TrueNAS Scale User Deleter"
    log_info "=========================="
    echo ""
    
    # Parse command line arguments
    parse_args "$@"
    
    # Load configuration
    load_config
    
    # Test connection to TrueNAS
    test_connection || exit 1
    
    # Handle different modes
    if [ "$LIST_USERS" = true ]; then
        list_all_users
        exit 0
    fi
    
    if [ -n "$USERNAME" ]; then
        # Single user deletion
        TOTAL_USERS=1
        delete_user "$USERNAME"
        print_summary
    elif [ -n "$CSV_FILE" ]; then
        # CSV file processing
        validate_csv "$CSV_FILE" || exit 1
        
        if [ "$FORCE" = false ]; then
            echo ""
            log_warning "You are about to delete $TOTAL_USERS user(s) from: $CSV_FILE"
            if [ "$PRESERVE_HOME" = false ]; then
                log_warning "Home directories will be deleted!"
            else
                log_info "Home directories will be preserved"
            fi
            echo ""
            read -p "Continue with deletion? (y/N): " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Operation cancelled by user"
                exit 0
            fi
        fi
        
        process_csv "$CSV_FILE"
        print_summary
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi