#!/bin/bash
#
# TrueNAS Scale User Creator
#
# This script reads user definitions from a CSV file and creates them
# using the TrueNAS Scale API via curl. It supports password generation,
# group management, home directory creation, and comprehensive validation.
#
# Usage: ./truenas_user_creator.sh [OPTIONS] <csv_file>
#
# Author: Generated for TrueNAS automation
#

set -euo pipefail

# Default values
CONFIG_FILE="config.env"
DRY_RUN=false
SKIP_EXISTING=false
VERBOSE=false
GENERATE_PASSWORDS=false
PASSWORD_FILE=""
CREATE_HOME_DIRS=false
CREATE_GROUPS=false
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
CREATED_USERS=0
SKIPPED_USERS=0
FAILED_USERS=0

# Arrays for tracking
CREATED_USER_LIST=()
FAILED_USER_LIST=()
GENERATED_PASSWORDS=()

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
Usage: $0 [OPTIONS] <csv_file>

Create TrueNAS users from CSV input file

OPTIONS:
    -c, --config FILE           Configuration file (default: config.env)
    --dry-run                   Show what would be created without actually creating users
    --skip-existing             Skip users that already exist
    --generate-passwords        Auto-generate passwords for users without them
    --password-file FILE        Save generated passwords to specified file
    --create-home-dirs          Automatically create home directories
    --create-groups             Automatically create missing groups
    -v, --verbose               Enable verbose logging
    -h, --help                  Show this help message

ARGUMENTS:
    csv_file                    Path to CSV file containing user definitions

EXAMPLE:
    $0 --dry-run users.csv
    $0 -c prod_config.env --skip-existing --generate-passwords --password-file passwords.txt users.csv

CSV FORMAT:
    Required columns: username, full_name
    Optional columns: password, email, uid, primary_group, secondary_groups,
                     home_directory, shell, locked, password_disabled, sudo_enabled,
                     ssh_public_key, quota, comments

    EXAMPLES:
    Basic CSV:
    username,full_name,email,primary_group
    jdoe,John Doe,jdoe@company.com,users
    
    Advanced CSV:
    username,full_name,password,uid,primary_group,secondary_groups,shell,sudo_enabled,comments
    admin,Admin User,SecurePass123,1500,wheel,"sudo,docker",/bin/bash,true,System Administrator

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
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-existing)
                SKIP_EXISTING=true
                shift
                ;;
            --generate-passwords)
                GENERATE_PASSWORDS=true
                shift
                ;;
            --password-file)
                PASSWORD_FILE="$2"
                shift 2
                ;;
            --create-home-dirs)
                CREATE_HOME_DIRS=true
                shift
                ;;
            --create-groups)
                CREATE_GROUPS=true
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
                if [ -z "$CSV_FILE" ]; then
                    CSV_FILE="$1"
                else
                    log_error "Multiple CSV files specified"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$CSV_FILE" ]; then
        log_error "CSV file is required"
        show_usage
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

# Default user settings
DEFAULT_SHELL="/usr/bin/bash"
DEFAULT_HOME_PREFIX="/mnt/tank/home"
DEFAULT_PASSWORD_DISABLED="false"
DEFAULT_PRIMARY_GROUP="users"

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
    DEFAULT_SHELL="${DEFAULT_SHELL:-/usr/bin/bash}"
    DEFAULT_HOME_PREFIX="${DEFAULT_HOME_PREFIX:-/mnt/tank/home}"
    DEFAULT_PASSWORD_DISABLED="${DEFAULT_PASSWORD_DISABLED:-false}"
    DEFAULT_PRIMARY_GROUP="${DEFAULT_PRIMARY_GROUP:-users}"
    DEFAULT_HOME_PERMISSIONS="${DEFAULT_HOME_PERMISSIONS:-755}"
    GENERATED_PASSWORD_LENGTH="${GENERATED_PASSWORD_LENGTH:-16}"
    PASSWORD_CHARSET="${PASSWORD_CHARSET:-ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*}"
    API_TIMEOUT="${API_TIMEOUT:-30}"
    MIN_USER_UID="${MIN_USER_UID:-1000}"
    MAX_USER_UID="${MAX_USER_UID:-65534}"
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
    
    # Check for required columns
    if [[ ! "$header" =~ username ]] || [[ ! "$header" =~ full_name ]]; then
        log_error "CSV file missing required columns: username, full_name"
        log_info "Found columns: $header"
        return 1
    fi
    
    # Count data lines (excluding header)
    local line_count
    line_count=$(tail -n +2 "$csv_file" | grep -c "^[^[:space:]]*," || true)
    
    if [ "$line_count" -eq 0 ]; then
        log_warning "No user data found in CSV file"
        return 1
    fi
    
    TOTAL_USERS=$line_count
    log_info "CSV validation successful: $TOTAL_USERS users found"
    return 0
}

# Function to generate a secure password
generate_password() {
    local length="${1:-$GENERATED_PASSWORD_LENGTH}"
    local charset="${2:-$PASSWORD_CHARSET}"
    
    # Use /dev/urandom to generate secure random password
    tr -dc "$charset" < /dev/urandom | head -c "$length"
}

# Function to validate email format
validate_email() {
    local email="$1"
    if [[ -z "$email" ]]; then
        return 0  # Empty email is valid (optional field)
    fi
    
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if user exists
user_exists() {
    local username="$1"
    
    local result
    result=$(truenas_api_call "GET" "/user?username=$username")
    local http_code="${result%%|*}"
    
    if [ "$http_code" = "200" ]; then
        return 0  # User exists
    else
        return 1  # User doesn't exist
    fi
}

# Function to check if group exists
group_exists() {
    local groupname="$1"
    
    local result
    result=$(truenas_api_call "GET" "/group?group=$groupname")
    local http_code="${result%%|*}"
    
    if [ "$http_code" = "200" ]; then
        return 0  # Group exists
    else
        return 1  # Group doesn't exist
    fi
}

# Function to create a group
create_group() {
    local groupname="$1"
    
    log_info "Creating group: $groupname"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would create group: $groupname"
        return 0
    fi
    
    local payload
    payload=$(cat <<EOF
{
    "name": "$groupname"
}
EOF
    )
    
    local result
    result=$(truenas_api_call "POST" "/group" "$payload")
    local http_code="${result%%|*}"
    local response_body="${result##*|}"
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        log_success "Group created successfully: $groupname"
        return 0
    else
        log_error "Failed to create group $groupname (HTTP $http_code)"
        log_debug "Response: $response_body"
        return 1
    fi
}

# Function to get next available UID
get_next_uid() {
    local result
    result=$(truenas_api_call "GET" "/user")
    local http_code="${result%%|*}"
    local response_body="${result##*|}"
    
    if [ "$http_code" = "200" ]; then
        # Extract UIDs and find the highest one
        local max_uid
        max_uid=$(echo "$response_body" | grep -o '"uid":[0-9]*' | cut -d':' -f2 | sort -n | tail -1)
        
        if [ -z "$max_uid" ] || [ "$max_uid" -lt "$MIN_USER_UID" ]; then
            echo "$MIN_USER_UID"
        else
            echo $((max_uid + 1))
        fi
    else
        # Fallback to minimum UID if we can't get user list
        echo "$MIN_USER_UID"
    fi
}

# Function to create home directory
create_home_directory() {
    local username="$1"
    local home_dir="$2"
    local uid="$3"
    
    log_info "Creating home directory: $home_dir"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would create home directory: $home_dir"
        return 0
    fi
    
    # Create directory via TrueNAS API
    local payload
    payload=$(cat <<EOF
{
    "path": "$home_dir",
    "options": {
        "mode": "$DEFAULT_HOME_PERMISSIONS"
    }
}
EOF
    )
    
    local result
    result=$(truenas_api_call "POST" "/filesystem/mkdir" "$payload")
    local http_code="${result%%|*}"
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        log_success "Home directory created: $home_dir"
        
        # Set ownership (this might require additional API call depending on TrueNAS version)
        log_debug "Home directory ownership will be set by TrueNAS user creation process"
        return 0
    else
        log_warning "Could not create home directory via API: $home_dir"
        log_debug "Home directory will be created by TrueNAS user creation process"
        return 1
    fi
}

# Function to parse CSV line and create user
parse_csv_line() {
    local line="$1"
    local line_num="$2"
    
    # Remove carriage returns and leading/trailing whitespace
    line=$(echo "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Skip empty lines
    if [ -z "$line" ]; then
        return 0
    fi
    
    # Parse CSV line (handle quoted fields)
    local IFS=','
    local fields=()
    
    # Simple CSV parsing (doesn't handle all edge cases but works for most data)
    while IFS=',' read -ra ADDR; do
        for field in "${ADDR[@]}"; do
            # Remove surrounding quotes if present
            field=$(echo "$field" | sed 's/^"//;s/"$//')
            fields+=("$field")
        done
    done <<< "$line"
    
    # Map fields to variables based on header
    local username="${fields[0]}"
    local full_name="${fields[1]}"
    local password="${fields[2]:-}"
    local email="${fields[3]:-}"
    local uid="${fields[4]:-}"
    local primary_group="${fields[5]:-$DEFAULT_PRIMARY_GROUP}"
    local secondary_groups="${fields[6]:-}"
    local home_directory="${fields[7]:-}"
    local shell="${fields[8]:-$DEFAULT_SHELL}"
    local locked="${fields[9]:-false}"
    local password_disabled="${fields[10]:-$DEFAULT_PASSWORD_DISABLED}"
    local sudo_enabled="${fields[11]:-false}"
    local ssh_public_key="${fields[12]:-}"
    local quota="${fields[13]:-}"
    local comments="${fields[14]:-}"
    
    # Validate required fields
    if [ -z "$username" ] || [ -z "$full_name" ]; then
        log_error "Line $line_num: Missing required fields (username, full_name)"
        return 1
    fi
    
    # Validate email if provided
    if [ -n "$email" ] && [ "${VALIDATE_EMAIL_FORMAT:-true}" = "true" ]; then
        if ! validate_email "$email"; then
            log_error "Line $line_num: Invalid email format: $email"
            return 1
        fi
    fi
    
    # Generate password if needed
    if [ -z "$password" ] && [ "$GENERATE_PASSWORDS" = true ]; then
        password=$(generate_password)
        GENERATED_PASSWORDS+=("$username:$password")
        log_info "Generated password for user: $username"
    fi
    
    # Set default home directory if not provided
    if [ -z "$home_directory" ]; then
        home_directory="$DEFAULT_HOME_PREFIX/$username"
    fi
    
    # Get UID if not provided
    if [ -z "$uid" ]; then
        uid=$(get_next_uid)
    fi
    
    # Validate UID range
    if [ "$uid" -lt "$MIN_USER_UID" ] || [ "$uid" -gt "$MAX_USER_UID" ]; then
        log_error "Line $line_num: UID $uid is outside allowed range ($MIN_USER_UID-$MAX_USER_UID)"
        return 1
    fi
    
    # Create user
    create_user "$username" "$full_name" "$password" "$email" "$uid" "$primary_group" \
                "$secondary_groups" "$home_directory" "$shell" "$locked" "$password_disabled" \
                "$sudo_enabled" "$ssh_public_key" "$quota" "$comments"
}

# Function to create a user
create_user() {
    local username="$1"
    local full_name="$2"
    local password="$3"
    local email="$4"
    local uid="$5"
    local primary_group="$6"
    local secondary_groups="$7"
    local home_directory="$8"
    local shell="$9"
    local locked="${10}"
    local password_disabled="${11}"
    local sudo_enabled="${12}"
    local ssh_public_key="${13}"
    local quota="${14}"
    local comments="${15}"
    
    log_info "Processing user: $username ($full_name)"
    
    # Check if user already exists
    if user_exists "$username"; then
        if [ "$SKIP_EXISTING" = true ]; then
            log_warning "User $username already exists, skipping"
            ((SKIPPED_USERS++))
            return 0
        else
            log_error "User $username already exists"
            ((FAILED_USERS++))
            FAILED_USER_LIST+=("$username")
            return 1
        fi
    fi
    
    # Check if primary group exists
    if ! group_exists "$primary_group"; then
        if [ "$CREATE_GROUPS" = true ]; then
            create_group "$primary_group" || {
                log_error "Failed to create primary group: $primary_group"
                ((FAILED_USERS++))
                FAILED_USER_LIST+=("$username")
                return 1
            }
        else
            log_error "Primary group does not exist: $primary_group"
            ((FAILED_USERS++))
            FAILED_USER_LIST+=("$username")
            return 1
        fi
    fi
    
    # Check secondary groups
    if [ -n "$secondary_groups" ]; then
        IFS=',' read -ra GROUPS <<< "$secondary_groups"
        for group in "${GROUPS[@]}"; do
            group=$(echo "$group" | xargs)  # Trim whitespace
            if ! group_exists "$group"; then
                if [ "$CREATE_GROUPS" = true ]; then
                    create_group "$group" || {
                        log_warning "Failed to create secondary group: $group"
                    }
                else
                    log_warning "Secondary group does not exist: $group (user will be created without this group)"
                fi
            fi
        done
    fi
    
    # Create home directory if requested
    if [ "$CREATE_HOME_DIRS" = true ]; then
        create_home_directory "$username" "$home_directory" "$uid"
    fi
    
    # Prepare user creation payload
    local payload
    payload=$(cat <<EOF
{
    "username": "$username",
    "full_name": "$full_name",
    "uid": $uid,
    "group": "$primary_group",
    "home": "$home_directory",
    "shell": "$shell",
    "locked": $([ "$locked" = "true" ] && echo "true" || echo "false"),
    "password_disabled": $([ "$password_disabled" = "true" ] && echo "true" || echo "false"),
    "sudo": $([ "$sudo_enabled" = "true" ] && echo "true" || echo "false")
EOF
    )
    
    # Add optional fields if provided
    if [ -n "$password" ]; then
        payload+=",\n    \"password\": \"$password\""
    fi
    
    if [ -n "$email" ]; then
        payload+=",\n    \"email\": \"$email\""
    fi
    
    if [ -n "$secondary_groups" ]; then
        # Convert comma-separated groups to JSON array
        local groups_json=""
        IFS=',' read -ra GROUPS <<< "$secondary_groups"
        for i in "${!GROUPS[@]}"; do
            local group=$(echo "${GROUPS[$i]}" | xargs)
            if [ $i -eq 0 ]; then
                groups_json="\"$group\""
            else
                groups_json+=", \"$group\""
            fi
        done
        payload+=",\n    \"groups\": [$groups_json]"
    fi
    
    if [ -n "$ssh_public_key" ]; then
        payload+=",\n    \"sshpubkey\": \"$ssh_public_key\""
    fi
    
    if [ -n "$comments" ]; then
        payload+=",\n    \"comment\": \"$comments\""
    fi
    
    payload+="\n}"
    
    # Execute user creation
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would create user: $username"
        log_debug "[DRY RUN] Payload: $(echo -e "$payload")"
        return 0
    fi
    
    log_debug "Creating user with payload: $(echo -e "$payload")"
    
    local result
    result=$(truenas_api_call "POST" "/user" "$(echo -e "$payload")")
    local http_code="${result%%|*}"
    local response_body="${result##*|}"
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        log_success "User created successfully: $username"
        ((CREATED_USERS++))
        CREATED_USER_LIST+=("$username")
        return 0
    else
        log_error "Failed to create user $username (HTTP $http_code)"
        log_debug "Response: $response_body"
        ((FAILED_USERS++))
        FAILED_USER_LIST+=("$username")
        return 1
    fi
}

# Function to save generated passwords
save_passwords() {
    if [ "$GENERATE_PASSWORDS" = true ] && [ -n "$PASSWORD_FILE" ] && [ ${#GENERATED_PASSWORDS[@]} -gt 0 ]; then
        log_info "Saving generated passwords to: $PASSWORD_FILE"
        
        # Create password file with secure permissions
        touch "$PASSWORD_FILE"
        chmod 600 "$PASSWORD_FILE"
        
        # Write header
        echo "# Generated passwords for TrueNAS users" > "$PASSWORD_FILE"
        echo "# Generated on: $(date)" >> "$PASSWORD_FILE"
        echo "# Format: username:password" >> "$PASSWORD_FILE"
        echo "" >> "$PASSWORD_FILE"
        
        # Write passwords
        for entry in "${GENERATED_PASSWORDS[@]}"; do
            echo "$entry" >> "$PASSWORD_FILE"
        done
        
        log_success "Saved ${#GENERATED_PASSWORDS[@]} passwords to $PASSWORD_FILE"
        log_warning "Password file contains sensitive information - secure it appropriately"
    fi
}

# Function to print summary
print_summary() {
    echo ""
    log_info "=========================="
    log_info "User Creation Summary"
    log_info "=========================="
    log_info "Total users processed: $TOTAL_USERS"
    log_info "Successfully created: $CREATED_USERS"
    log_info "Skipped (already exist): $SKIPPED_USERS"
    log_info "Failed: $FAILED_USERS"
    
    if [ ${#CREATED_USER_LIST[@]} -gt 0 ]; then
        echo ""
        log_success "Successfully created users:"
        for user in "${CREATED_USER_LIST[@]}"; do
            echo "  - $user"
        done
    fi
    
    if [ ${#FAILED_USER_LIST[@]} -gt 0 ]; then
        echo ""
        log_error "Failed to create users:"
        for user in "${FAILED_USER_LIST[@]}"; do
            echo "  - $user"
        done
    fi
    
    if [ "$GENERATE_PASSWORDS" = true ] && [ ${#GENERATED_PASSWORDS[@]} -gt 0 ]; then
        echo ""
        log_info "Generated passwords for ${#GENERATED_PASSWORDS[@]} users"
        if [ -n "$PASSWORD_FILE" ]; then
            log_info "Passwords saved to: $PASSWORD_FILE"
        else
            log_warning "Generated passwords not saved to file (use --password-file option)"
        fi
    fi
    
    echo ""
    if [ "$FAILED_USERS" -eq 0 ]; then
        log_success "All users processed successfully!"
        exit 0
    else
        log_warning "Some users failed to be created. Check the logs above for details."
        exit 1
    fi
}

# Main function
main() {
    echo ""
    log_info "TrueNAS Scale User Creator"
    log_info "=========================="
    echo ""
    
    # Parse command line arguments
    parse_args "$@"
    
    # Load configuration
    load_config
    
    # Validate CSV file
    validate_csv "$CSV_FILE" || exit 1
    
    # Test connection to TrueNAS
    test_connection || exit 1
    
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY RUN MODE - No changes will be made"
        echo ""
    fi
    
    # Process CSV file
    log_info "Processing users from: $CSV_FILE"
    echo ""
    
    local line_num=1
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip header line
        if [ $line_num -eq 2 ]; then
            continue
        fi
        
        parse_csv_line "$line" "$line_num" || continue
    done < "$CSV_FILE"
    
    # Save generated passwords
    save_passwords
    
    # Print summary
    print_summary
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi