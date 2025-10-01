#!/bin/bash
#
# TrueNAS Scale Share Creator
#
# This script reads share definitions from a CSV file and creates them
# using the TrueNAS Scale API via curl. Supports both SMB and NFS shares.
#
# Usage: ./truenas_share_creator.sh [OPTIONS] <csv_file>
#
# Author: Generated for TrueNAS automation
#

set -euo pipefail

# Default values
CONFIG_FILE="config.env"
DRY_RUN=false
SKIP_EXISTING=false
VERBOSE=false
CSV_FILE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] <csv_file>

Create TrueNAS SMB and NFS shares from CSV input file

OPTIONS:
    -c, --config FILE       Configuration file (default: config.env)
    --dry-run              Show what would be created without actually creating shares
    --skip-existing        Skip shares that already exist
    -v, --verbose          Enable verbose logging
    -h, --help             Show this help message

ARGUMENTS:
    csv_file               Path to CSV file containing share definitions

EXAMPLE:
    $0 --dry-run shares.csv
    $0 -c my_config.env --skip-existing shares.csv

CSV FORMAT:
    Required columns: type, name, path
    Optional columns vary by share type
    
    SMB SHARES:
    - type: "smb"
    - name: Share name (as shown in network)
    - path: Full path to shared directory
    - comment: Description of the share
    - enabled: true/false (enable/disable share)
    - browsable: true/false (show in network browser)
    - recyclable: true/false (enable recycle bin)
    - guestok: true/false (allow guest access)
    - aapl_name_mangling: true/false (Apple name mangling)
    - aapl_extensions: true/false (Apple protocol extensions)
    - aapl_metadata: true/false (Apple metadata)
    - shadowcopy: true/false (enable shadow copies)
    - ro: true/false (read-only access)
    
    NFS SHARES:
    - type: "nfs"  
    - name: Share name (for identification)
    - path: Full path to shared directory
    - comment: Description of the share
    - enabled: true/false (enable/disable share)
    - ro: true/false (read-only access)
    - maproot: root mapping user (e.g., "root", "nobody")
    - mapall: all users mapping (e.g., "nobody")
    - security: security options
    - networks: allowed networks (space or comma separated)
    - hosts: allowed hosts (space or comma separated)  
    - alldirs: true/false (allow access to all subdirectories)
    - quiet: true/false (suppress syslog messages)

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

    # Set default for SSL verification
    VERIFY_SSL="${VERIFY_SSL:-true}"
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

    if [ "$VERIFY_SSL" != "true" ]; then
        curl_opts+=(-k)
    fi

    case "$method" in
        "POST")
            if [ -n "$data" ]; then
                curl_opts+=(-X POST -d "$data")
            fi
            ;;
        "PUT")
            if [ -n "$data" ]; then
                curl_opts+=(-X PUT -d "$data")
            fi
            ;;
        "DELETE")
            curl_opts+=(-X DELETE)
            ;;
    esac

    log_debug "API Call: $method ${TRUENAS_HOST}/api/v2.0${endpoint}" >&2
    if [ -n "$data" ]; then
        log_debug "Payload: $data" >&2
    fi

    curl "${curl_opts[@]}" "${TRUENAS_HOST}/api/v2.0${endpoint}"
}

# Function to test connection to TrueNAS
test_connection() {
    log_info "Testing connection to TrueNAS API..."
    
    local response
    response=$(truenas_api_call "GET" "/system/info")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Successfully connected to TrueNAS API"
        return 0
    else
        log_error "Failed to connect to TrueNAS API (HTTP $http_code)"
        log_debug "Response: $body"
        return 1
    fi
}

# Function to check if SMB share exists
smb_share_exists() {
    local share_name="$1"
    
    log_debug "Checking if SMB share exists: $share_name"
    
    local response
    response=$(truenas_api_call "GET" "/sharing/smb")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        # Check if share name exists in the response
        if echo "$body" | grep -q "\"name\":\"$share_name\""; then
            return 0  # Share exists
        else
            return 1  # Share doesn't exist
        fi
    else
        log_error "Failed to get SMB shares (HTTP $http_code)"
        return 1
    fi
}

# Function to check if NFS share exists
nfs_share_exists() {
    local share_path="$1"
    
    log_debug "Checking if NFS share exists for path: $share_path"
    
    local response
    response=$(truenas_api_call "GET" "/sharing/nfs")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        # Check if path exists in the response
        if echo "$body" | grep -q "\"path\":\"$share_path\""; then
            return 0  # Share exists
        else
            return 1  # Share doesn't exist
        fi
    else
        log_error "Failed to get NFS shares (HTTP $http_code)"
        return 1
    fi
}

# Function to build SMB share JSON configuration
build_smb_config() {
    local name="$1"
    local path="$2"
    local comment="${3:-}"
    local enabled="${4:-true}"
    local browsable="${5:-true}"
    local recyclable="${6:-false}"
    local guestok="${7:-false}"
    local aapl_name_mangling="${8:-false}"
    local aapl_extensions="${9:-false}"
    local aapl_metadata="${10:-false}"
    local shadowcopy="${11:-false}"
    local ro="${12:-false}"

    # Start building JSON
    local json="{\"name\":\"$name\",\"path\":\"$path\""

    # Add optional fields
    [ -n "$comment" ] && json="$json,\"comment\":\"$comment\""
    
    # Convert boolean strings to JSON booleans
    local enabled_bool=$([ "$enabled" = "true" ] && echo "true" || echo "false")
    local browsable_bool=$([ "$browsable" = "true" ] && echo "true" || echo "false")
    local recyclable_bool=$([ "$recyclable" = "true" ] && echo "true" || echo "false")
    local guestok_bool=$([ "$guestok" = "true" ] && echo "true" || echo "false")
    local aapl_name_mangling_bool=$([ "$aapl_name_mangling" = "true" ] && echo "true" || echo "false")
    local aapl_extensions_bool=$([ "$aapl_extensions" = "true" ] && echo "true" || echo "false")
    local aapl_metadata_bool=$([ "$aapl_metadata" = "true" ] && echo "true" || echo "false")
    local shadowcopy_bool=$([ "$shadowcopy" = "true" ] && echo "true" || echo "false")
    local ro_bool=$([ "$ro" = "true" ] && echo "true" || echo "false")

    json="$json,\"enabled\":$enabled_bool"
    json="$json,\"browsable\":$browsable_bool"
    json="$json,\"recyclebin\":$recyclable_bool"
    json="$json,\"guestok\":$guestok_bool"
    json="$json,\"aapl_name_mangling\":$aapl_name_mangling_bool"
    json="$json,\"aapl_extensions\":$aapl_extensions_bool"
    json="$json,\"fruit_metadata\":$aapl_metadata_bool"
    json="$json,\"shadowcopy\":$shadowcopy_bool"
    json="$json,\"ro\":$ro_bool"

    json="$json}"
    echo "$json"
}

# Function to build NFS share JSON configuration  
build_nfs_config() {
    local path="$1"
    local comment="${2:-}"
    local enabled="${3:-true}"
    local ro="${4:-false}"
    local maproot="${5:-}"
    local mapall="${6:-}"
    local security="${7:-}"
    local networks="${8:-}"
    local hosts="${9:-}"
    local alldirs="${10:-false}"
    local quiet="${11:-false}"

    # Start building JSON
    local json="{\"path\":\"$path\""

    # Add comment if provided
    [ -n "$comment" ] && json="$json,\"comment\":\"$comment\""
    
    # Convert boolean strings
    local enabled_bool=$([ "$enabled" = "true" ] && echo "true" || echo "false")
    local ro_bool=$([ "$ro" = "true" ] && echo "true" || echo "false")
    local alldirs_bool=$([ "$alldirs" = "true" ] && echo "true" || echo "false")
    local quiet_bool=$([ "$quiet" = "true" ] && echo "true" || echo "false")

    json="$json,\"enabled\":$enabled_bool"
    json="$json,\"ro\":$ro_bool"
    json="$json,\"alldirs\":$alldirs_bool"
    json="$json,\"quiet\":$quiet_bool"

    # Add mapping options
    [ -n "$maproot" ] && json="$json,\"maproot_user\":\"$maproot\""
    [ -n "$mapall" ] && json="$json,\"mapall_user\":\"$mapall\""
    [ -n "$security" ] && json="$json,\"security\":[\"$security\"]"

    # Handle networks and hosts (convert space/comma separated to array)
    if [ -n "$networks" ]; then
        local networks_array=""
        IFS=$' \t\n,'
        for network in $networks; do
            [ -n "$network" ] && {
                [ -n "$networks_array" ] && networks_array="$networks_array,"
                networks_array="$networks_array\"$network\""
            }
        done
        [ -n "$networks_array" ] && json="$json,\"networks\":[$networks_array]"
        unset IFS
    fi

    if [ -n "$hosts" ]; then
        local hosts_array=""
        IFS=$' \t\n,'
        for host in $hosts; do
            [ -n "$host" ] && {
                [ -n "$hosts_array" ] && hosts_array="$hosts_array,"
                hosts_array="$hosts_array\"$host\""
            }
        done
        [ -n "$hosts_array" ] && json="$json,\"hosts\":[$hosts_array]"
        unset IFS
    fi

    json="$json}"
    echo "$json"
}

# Function to create SMB share
create_smb_share() {
    local config="$1"
    local share_name
    share_name=$(echo "$config" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
    
    log_debug "Creating SMB share with config: $config"
    
    local response
    response=$(truenas_api_call "POST" "/sharing/smb" "$config")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Successfully created SMB share: $share_name"
        return 0
    else
        log_error "Failed to create SMB share $share_name (HTTP $http_code)"
        log_debug "Response: $body"
        return 1
    fi
}

# Function to create NFS share
create_nfs_share() {
    local config="$1"
    local share_path
    share_path=$(echo "$config" | grep -o '"path":"[^"]*"' | cut -d'"' -f4)
    
    log_debug "Creating NFS share with config: $config"
    
    local response
    response=$(truenas_api_call "POST" "/sharing/nfs" "$config")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Successfully created NFS share: $share_path"
        return 0
    else
        log_error "Failed to create NFS share $share_path (HTTP $http_code)"
        log_debug "Response: $body"
        return 1
    fi
}

# Function to validate CSV file
validate_csv_file() {
    if [ ! -f "$CSV_FILE" ]; then
        log_error "CSV file not found: $CSV_FILE"
        exit 1
    fi

    # Check if file has required headers
    local header_line
    header_line=$(head -n1 "$CSV_FILE")
    
    if [[ ! "$header_line" =~ "type" ]] || [[ ! "$header_line" =~ "name" ]] || [[ ! "$header_line" =~ "path" ]]; then
        log_error "CSV file must contain 'type', 'name', and 'path' columns"
        log_info "Current header line: $header_line"
        exit 1
    fi

    log_success "CSV file validation passed"
}

# Function to process CSV file
process_csv_file() {
    local success_count=0
    local error_count=0
    local skipped_count=0
    local total_count=0

    # Read CSV header to get column positions
    local header
    header=$(head -n1 "$CSV_FILE")
    
    log_debug "CSV Header: $header"

    # Skip header line and process each data row
    while IFS=',' read -r type name path comment enabled browsable recyclable guestok aapl_name_mangling aapl_extensions aapl_metadata shadowcopy ro maproot mapall security networks hosts alldirs quiet _; do
        # Remove quotes if present
        type=$(echo "$type" | sed 's/^"//; s/"$//')
        name=$(echo "$name" | sed 's/^"//; s/"$//')
        path=$(echo "$path" | sed 's/^"//; s/"$//')
        
        # Skip empty lines
        [ -z "$type" ] && [ -z "$name" ] && [ -z "$path" ] && continue
        
        total_count=$((total_count + 1))
        
        log_info "Processing share $total_count: $name ($type)"

        # Validate share type
        if [ "$type" != "smb" ] && [ "$type" != "nfs" ]; then
            log_error "Invalid share type '$type' for share '$name'. Must be 'smb' or 'nfs'"
            error_count=$((error_count + 1))
            continue
        fi

        # Check if share already exists
        local exists=false
        if [ "$type" = "smb" ]; then
            if [ "$SKIP_EXISTING" = true ] && smb_share_exists "$name"; then
                exists=true
            fi
        else
            if [ "$SKIP_EXISTING" = true ] && nfs_share_exists "$path"; then
                exists=true
            fi
        fi

        if [ "$exists" = true ]; then
            log_warning "Share already exists, skipping: $name"
            skipped_count=$((skipped_count + 1))
            continue
        fi

        # Build configuration based on share type
        local config
        if [ "$type" = "smb" ]; then
            config=$(build_smb_config "$name" "$path" "$comment" "$enabled" "$browsable" "$recyclable" "$guestok" "$aapl_name_mangling" "$aapl_extensions" "$aapl_metadata" "$shadowcopy" "$ro")
        else
            config=$(build_nfs_config "$path" "$comment" "$enabled" "$ro" "$maproot" "$mapall" "$security" "$networks" "$hosts" "$alldirs" "$quiet")
        fi

        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would create $type share with config:"
            echo "$config" | python3 -m json.tool 2>/dev/null || echo "$config"
            success_count=$((success_count + 1))
        else
            if [ "$type" = "smb" ]; then
                if create_smb_share "$config"; then
                    success_count=$((success_count + 1))
                else
                    error_count=$((error_count + 1))
                fi
            else
                if create_nfs_share "$config"; then
                    success_count=$((success_count + 1))
                else
                    error_count=$((error_count + 1))
                fi
            fi
        fi
    done < <(tail -n +2 "$CSV_FILE")

    # Summary
    log_info ""
    log_info "Share creation summary:"
    log_info "- Successful: $success_count"
    log_info "- Errors: $error_count" 
    log_info "- Skipped: $skipped_count"
    log_info "- Total processed: $total_count"

    if [ $error_count -gt 0 ]; then
        exit 1
    fi
}

# Main function
main() {
    echo "TrueNAS Scale Share Creator"
    echo "=========================="
    echo

    parse_args "$@"
    load_config
    validate_csv_file

    if ! test_connection; then
        exit 1
    fi

    process_csv_file
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi