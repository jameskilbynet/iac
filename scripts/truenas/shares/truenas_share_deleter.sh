#!/bin/bash
#
# TrueNAS Scale Share Deleter
#
# This script removes SMB and NFS shares from TrueNAS Scale using the REST API.
# It can delete shares specified in a CSV file or by individual name/path.
#
# Usage: ./truenas_share_deleter.sh [OPTIONS] [<csv_file>|--name <share_name>|--path <share_path>]
#
# Author: Generated for TrueNAS automation
#

set -euo pipefail

# Default values
CONFIG_FILE="config.env"
DRY_RUN=false
FORCE=false
VERBOSE=false
CSV_FILE=""
SHARE_NAME=""
SHARE_PATH=""
SHARE_TYPE=""

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
Usage: $0 [OPTIONS] [<csv_file>|--name <share_name>|--path <share_path>]

Remove TrueNAS SMB and NFS shares

OPTIONS:
    -c, --config FILE       Configuration file (default: config.env)
    --dry-run              Show what would be deleted without actually removing shares
    --force                Skip confirmation prompts (use with caution)
    -v, --verbose          Enable verbose logging
    -h, --help             Show this help message

DELETION MODES:
    CSV Mode:
        $0 [OPTIONS] shares_to_delete.csv
        
    Individual Share Mode:
        --name <name> --type <smb|nfs>    Delete specific SMB share by name or NFS by identifier
        --path <path> --type nfs          Delete NFS share by path
        --type smb --list                 List all SMB shares
        --type nfs --list                 List all NFS shares

EXAMPLES:
    # Delete shares from CSV file (dry run first)
    $0 --dry-run shares_to_delete.csv
    $0 shares_to_delete.csv
    
    # Delete individual SMB share
    $0 --name "media-share" --type smb
    
    # Delete individual NFS share by path
    $0 --path "/mnt/tank/backup" --type nfs
    
    # List existing shares
    $0 --type smb --list
    $0 --type nfs --list
    
    # Force delete without confirmation
    $0 --force --name "old-share" --type smb

CSV FORMAT (for bulk deletion):
    Required columns: type, identifier
    - type: "smb" or "nfs"
    - identifier: For SMB shares, use the share name. For NFS shares, use the path.
    
    Example CSV:
    type,identifier,comment
    smb,old-media,Old media share
    smb,temp-docs,Temporary documents
    nfs,/mnt/tank/old-backup,Old backup location
    nfs,/mnt/tank/temp,Temporary NFS share

EOF
}

# Function to parse command line arguments
parse_args() {
    local list_mode=false
    
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
            --force)
                FORCE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --name)
                SHARE_NAME="$2"
                shift 2
                ;;
            --path)
                SHARE_PATH="$2"
                shift 2
                ;;
            --type)
                SHARE_TYPE="$2"
                shift 2
                ;;
            --list)
                list_mode=true
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
                if [ -z "$CSV_FILE" ] && [ -z "$SHARE_NAME" ] && [ -z "$SHARE_PATH" ] && [ "$list_mode" = false ]; then
                    CSV_FILE="$1"
                else
                    log_error "Too many arguments or conflicting options"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Validate arguments
    if [ "$list_mode" = true ]; then
        if [ -z "$SHARE_TYPE" ]; then
            log_error "--list requires --type (smb or nfs)"
            exit 1
        fi
        if [ "$SHARE_TYPE" != "smb" ] && [ "$SHARE_TYPE" != "nfs" ]; then
            log_error "Share type must be 'smb' or 'nfs'"
            exit 1
        fi
        # Set a flag to handle list mode in main
        LIST_MODE=true
        return 0
    fi

    if [ -z "$CSV_FILE" ] && [ -z "$SHARE_NAME" ] && [ -z "$SHARE_PATH" ]; then
        log_error "Must specify either a CSV file, --name, or --path"
        show_usage
        exit 1
    fi

    if [ -n "$SHARE_NAME" ] || [ -n "$SHARE_PATH" ]; then
        if [ -z "$SHARE_TYPE" ]; then
            log_error "--name and --path require --type (smb or nfs)"
            exit 1
        fi
        if [ "$SHARE_TYPE" != "smb" ] && [ "$SHARE_TYPE" != "nfs" ]; then
            log_error "Share type must be 'smb' or 'nfs'"
            exit 1
        fi
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

# Function to get SMB shares
get_smb_shares() {
    log_debug "Fetching SMB shares..."
    
    local response
    response=$(truenas_api_call "GET" "/sharing/smb")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        echo "$body"
        return 0
    else
        log_error "Failed to get SMB shares (HTTP $http_code)"
        log_debug "Response: $body"
        return 1
    fi
}

# Function to get NFS shares
get_nfs_shares() {
    log_debug "Fetching NFS shares..."
    
    local response
    response=$(truenas_api_call "GET" "/sharing/nfs")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        echo "$body"
        return 0
    else
        log_error "Failed to get NFS shares (HTTP $http_code)"
        log_debug "Response: $body"
        return 1
    fi
}

# Function to find SMB share ID by name
find_smb_share_id() {
    local share_name="$1"
    local shares_json="$2"
    
    log_debug "Looking for SMB share: $share_name"
    
    # Use Python to parse JSON and find share ID
    if command -v python3 >/dev/null 2>&1; then
        echo "$shares_json" | python3 -c "
import json, sys
try:
    shares = json.load(sys.stdin)
    for share in shares:
        if share.get('name') == '$share_name':
            print(share.get('id', ''))
            sys.exit(0)
except:
    pass
"
    else
        # Fallback to grep/sed approach
        echo "$shares_json" | grep -A5 -B5 "\"name\":\"$share_name\"" | grep '"id":' | head -1 | sed 's/.*"id": *\([0-9]*\).*/\1/'
    fi
}

# Function to find NFS share ID by path
find_nfs_share_id() {
    local share_path="$1"
    local shares_json="$2"
    
    log_debug "Looking for NFS share with path: $share_path"
    
    # Use Python to parse JSON and find share ID
    if command -v python3 >/dev/null 2>&1; then
        echo "$shares_json" | python3 -c "
import json, sys
try:
    shares = json.load(sys.stdin)
    for share in shares:
        if share.get('path') == '$share_path':
            print(share.get('id', ''))
            sys.exit(0)
except:
    pass
"
    else
        # Fallback to grep/sed approach
        echo "$shares_json" | grep -A5 -B5 "\"path\":\"$share_path\"" | grep '"id":' | head -1 | sed 's/.*"id": *\([0-9]*\).*/\1/'
    fi
}

# Function to list shares
list_shares() {
    local share_type="$1"
    
    if [ "$share_type" = "smb" ]; then
        log_info "SMB Shares:"
        local smb_shares
        smb_shares=$(get_smb_shares) || return 1
        
        if command -v python3 >/dev/null 2>&1; then
            echo "$smb_shares" | python3 -c "
import json, sys
try:
    shares = json.load(sys.stdin)
    if not shares:
        print('  No SMB shares found')
    else:
        for share in shares:
            enabled = '✓' if share.get('enabled', False) else '✗'
            print(f'  [{share.get(\"id\", \"?\")}] {share.get(\"name\", \"unnamed\")} -> {share.get(\"path\", \"no path\")} ({enabled})')
except Exception as e:
    print('  Error parsing SMB shares')
"
        else
            echo "$smb_shares" | grep -E '"(id|name|path|enabled)"' | paste - - - - | sed 's/.*"id": *\([0-9]*\).*/[\1]/' 
        fi
    else
        log_info "NFS Shares:"
        local nfs_shares
        nfs_shares=$(get_nfs_shares) || return 1
        
        if command -v python3 >/dev/null 2>&1; then
            echo "$nfs_shares" | python3 -c "
import json, sys
try:
    shares = json.load(sys.stdin)
    if not shares:
        print('  No NFS shares found')
    else:
        for share in shares:
            enabled = '✓' if share.get('enabled', False) else '✗'
            networks = ', '.join(share.get('networks', [])) or 'any'
            print(f'  [{share.get(\"id\", \"?\")}] {share.get(\"path\", \"no path\")} -> {networks} ({enabled})')
except Exception as e:
    print('  Error parsing NFS shares')
"
        else
            echo "$nfs_shares" | grep -E '"(id|path|enabled)"' | paste - - - | sed 's/.*"id": *\([0-9]*\).*/[\1]/'
        fi
    fi
}

# Function to delete SMB share
delete_smb_share() {
    local share_id="$1"
    local share_name="$2"
    
    log_debug "Deleting SMB share ID $share_id ($share_name)"
    
    local response
    response=$(truenas_api_call "DELETE" "/sharing/smb/id/$share_id")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Successfully deleted SMB share: $share_name (ID: $share_id)"
        return 0
    else
        log_error "Failed to delete SMB share $share_name (HTTP $http_code)"
        log_debug "Response: $body"
        return 1
    fi
}

# Function to delete NFS share
delete_nfs_share() {
    local share_id="$1"
    local share_path="$2"
    
    log_debug "Deleting NFS share ID $share_id ($share_path)"
    
    local response
    response=$(truenas_api_call "DELETE" "/sharing/nfs/id/$share_id")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Successfully deleted NFS share: $share_path (ID: $share_id)"
        return 0
    else
        log_error "Failed to delete NFS share $share_path (HTTP $http_code)"
        log_debug "Response: $body"
        return 1
    fi
}

# Function to confirm deletion
confirm_deletion() {
    local share_type="$1"
    local identifier="$2"
    
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    echo -n "Are you sure you want to delete the $share_type share '$identifier'? [y/N]: "
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            log_info "Deletion cancelled"
            return 1
            ;;
    esac
}

# Function to process individual share deletion
process_individual_share() {
    local share_type="$1"
    local identifier="$2"
    
    if [ "$share_type" = "smb" ]; then
        local smb_shares
        smb_shares=$(get_smb_shares) || return 1
        
        local share_id
        share_id=$(find_smb_share_id "$identifier" "$smb_shares")
        
        if [ -z "$share_id" ]; then
            log_error "SMB share not found: $identifier"
            return 1
        fi
        
        log_info "Found SMB share: $identifier (ID: $share_id)"
        
        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would delete SMB share: $identifier (ID: $share_id)"
            return 0
        fi
        
        if confirm_deletion "SMB" "$identifier"; then
            delete_smb_share "$share_id" "$identifier"
        else
            return 1
        fi
        
    else # nfs
        local nfs_shares
        nfs_shares=$(get_nfs_shares) || return 1
        
        local share_id
        share_id=$(find_nfs_share_id "$identifier" "$nfs_shares")
        
        if [ -z "$share_id" ]; then
            log_error "NFS share not found: $identifier"
            return 1
        fi
        
        log_info "Found NFS share: $identifier (ID: $share_id)"
        
        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would delete NFS share: $identifier (ID: $share_id)"
            return 0
        fi
        
        if confirm_deletion "NFS" "$identifier"; then
            delete_nfs_share "$share_id" "$identifier"
        else
            return 1
        fi
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
    
    if [[ ! "$header_line" =~ "type" ]] || [[ ! "$header_line" =~ "identifier" ]]; then
        log_error "CSV file must contain 'type' and 'identifier' columns"
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

    # Get all shares upfront
    log_info "Fetching existing shares..."
    local smb_shares nfs_shares
    smb_shares=$(get_smb_shares) || { log_error "Failed to fetch SMB shares"; exit 1; }
    nfs_shares=$(get_nfs_shares) || { log_error "Failed to fetch NFS shares"; exit 1; }

    # Skip header line and process each data row
    while IFS=',' read -r type identifier comment _; do
        # Remove quotes if present
        type=$(echo "$type" | sed 's/^"//; s/"$//')
        identifier=$(echo "$identifier" | sed 's/^"//; s/"$//')
        
        # Skip empty lines
        [ -z "$type" ] && [ -z "$identifier" ] && continue
        
        total_count=$((total_count + 1))
        
        log_info "Processing deletion $total_count: $identifier ($type)"

        # Validate share type
        if [ "$type" != "smb" ] && [ "$type" != "nfs" ]; then
            log_error "Invalid share type '$type' for identifier '$identifier'. Must be 'smb' or 'nfs'"
            error_count=$((error_count + 1))
            continue
        fi

        # Find share ID
        local share_id=""
        if [ "$type" = "smb" ]; then
            share_id=$(find_smb_share_id "$identifier" "$smb_shares")
        else
            share_id=$(find_nfs_share_id "$identifier" "$nfs_shares")
        fi

        if [ -z "$share_id" ]; then
            log_warning "Share not found, skipping: $identifier ($type)"
            skipped_count=$((skipped_count + 1))
            continue
        fi

        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would delete $type share: $identifier (ID: $share_id)"
            success_count=$((success_count + 1))
        else
            # Confirm deletion unless forced
            if [ "$FORCE" = false ]; then
                if ! confirm_deletion "$type" "$identifier"; then
                    log_info "Skipping deletion of: $identifier"
                    skipped_count=$((skipped_count + 1))
                    continue
                fi
            fi
            
            if [ "$type" = "smb" ]; then
                if delete_smb_share "$share_id" "$identifier"; then
                    success_count=$((success_count + 1))
                else
                    error_count=$((error_count + 1))
                fi
            else
                if delete_nfs_share "$share_id" "$identifier"; then
                    success_count=$((success_count + 1))
                else
                    error_count=$((error_count + 1))
                fi
            fi
        fi
    done < <(tail -n +2 "$CSV_FILE")

    # Summary
    log_info ""
    log_info "Share deletion summary:"
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
    echo "TrueNAS Scale Share Deleter"
    echo "==========================="
    echo

    parse_args "$@"
    load_config

    if ! test_connection; then
        exit 1
    fi

    # Handle list mode
    if [ "${LIST_MODE:-false}" = true ]; then
        list_shares "$SHARE_TYPE"
        exit 0
    fi

    # Handle CSV mode
    if [ -n "$CSV_FILE" ]; then
        validate_csv_file
        process_csv_file
        exit 0
    fi

    # Handle individual share mode
    local identifier
    if [ -n "$SHARE_NAME" ]; then
        identifier="$SHARE_NAME"
    elif [ -n "$SHARE_PATH" ]; then
        identifier="$SHARE_PATH"
    fi

    if [ -n "$identifier" ]; then
        if process_individual_share "$SHARE_TYPE" "$identifier"; then
            log_success "Share deletion completed successfully"
        else
            log_error "Share deletion failed"
            exit 1
        fi
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi