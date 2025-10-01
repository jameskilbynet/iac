#!/bin/bash
#
# TrueNAS Scale Pool Manager
#
# This script manages TrueNAS Scale storage pools via the REST API.
# Supports listing, creating, and managing ZFS pools.
#
# Usage: ./truenas_pool_manager.sh [OPTIONS] [COMMAND] [arguments]
#
# Author: Generated for TrueNAS automation
#

set -euo pipefail

# Default values
CONFIG_FILE="config.env"
DRY_RUN=false
FORCE=false
VERBOSE=false
COMMAND=""
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
Usage: $0 [OPTIONS] <COMMAND> [arguments]

Manage TrueNAS Scale storage pools via REST API

COMMANDS:
    list                    List all storage pools with status
    create <csv_file>       Create pools from CSV file
    status [pool_name]      Show detailed status for pool(s)
    scrub <pool_name>       Start scrub on specified pool
    export <pool_name>      Export/remove pool (with confirmation)
    import                  Import available pools
    disks                   List available disks for pool creation

OPTIONS:
    -c, --config FILE       Configuration file (default: config.env)
    --dry-run              Show what would be done without executing
    --force                Skip confirmation prompts
    -v, --verbose          Enable verbose logging
    -h, --help             Show this help message

EXAMPLES:
    $0 list                           # List all pools
    $0 status tank                    # Show tank pool status
    $0 create pools.csv               # Create pools from CSV
    $0 --dry-run create pools.csv     # Preview pool creation
    $0 scrub tank                     # Start scrub on tank pool
    $0 disks                          # List available disks

CSV FORMAT for create command:
    Required columns: name, topology
    Optional columns: encryption, compression, atime, checksum,
                     dedup, recordsize, volsize, volblocksize
    
    TOPOLOGY FORMATS:
    - stripe: disk1,disk2,disk3
    - mirror: mirror:disk1,disk2
    - raidz1: raidz1:disk1,disk2,disk3
    - raidz2: raidz2:disk1,disk2,disk3,disk4
    - raidz3: raidz3:disk1,disk2,disk3,disk4,disk5
    - Complex: raidz2:disk1,disk2,disk3,disk4 mirror:disk5,disk6
    
    ENCRYPTION:
    - true: Enable encryption with auto-generated key
    - false: No encryption (default)
    - passphrase:your_passphrase: Use passphrase-based encryption

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
            --force)
                FORCE=true
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
            list|status|create|scrub|export|import|disks)
                if [ -z "$COMMAND" ]; then
                    COMMAND="$1"
                    shift
                else
                    log_error "Multiple commands specified"
                    exit 1
                fi
                ;;
            -*) 
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                # Command argument
                if [ "$COMMAND" = "create" ] && [ -z "$CSV_FILE" ]; then
                    CSV_FILE="$1"
                elif [ "$COMMAND" = "status" ] || [ "$COMMAND" = "scrub" ] || [ "$COMMAND" = "export" ]; then
                    POOL_NAME="$1"
                else
                    log_error "Unexpected argument: $1"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$COMMAND" ]; then
        log_error "Command is required"
        show_usage
        exit 1
    fi

    if [ "$COMMAND" = "create" ] && [ -z "$CSV_FILE" ]; then
        log_error "CSV file is required for create command"
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

    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        curl_opts+=(-X POST -d "$data")
    elif [ "$method" = "DELETE" ]; then
        curl_opts+=(-X DELETE)
    fi

    log_debug "API Call: $method ${TRUENAS_HOST}/api/v2.0${endpoint}"
    if [ -n "$data" ]; then
        log_debug "Payload: $data"
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

# Function to list all pools
list_pools() {
    log_info "Fetching storage pools..."
    
    local response
    response=$(truenas_api_call "GET" "/pool")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Storage pools retrieved successfully"
        echo
        printf "%-15s %-10s %-15s %-15s %-20s\n" "NAME" "STATUS" "HEALTH" "SIZE" "AVAILABLE"
        printf "%-15s %-10s %-15s %-15s %-20s\n" "----" "------" "------" "----" "---------"
        
        if command -v jq >/dev/null 2>&1; then
            echo "$body" | jq -r '.[] | "\(.name)\t\(.status)\t\(.healthy // "N/A")\t\(.size // "N/A")\t\(.available // "N/A")"' | \
            while IFS=$'\t' read -r name status health size available; do
                printf "%-15s %-10s %-15s %-15s %-20s\n" "$name" "$status" "$health" "$size" "$available"
            done
        else
            # Fallback parsing without jq
            echo "$body" | grep -o '"name": *"[^"]*"' | sed 's/.*"name": *"\([^"]*\)".*/\1/' | \
            while read -r pool_name; do
                printf "%-15s %-10s %-15s %-15s %-20s\n" "$pool_name" "ONLINE" "N/A" "N/A" "N/A"
            done
        fi
        return 0
    else
        log_error "Failed to get pools (HTTP $http_code)"
        log_debug "Response: $body"
        return 1
    fi
}

# Function to show detailed pool status
show_pool_status() {
    local pool_name="${POOL_NAME:-}"
    
    if [ -n "$pool_name" ]; then
        log_info "Getting status for pool: $pool_name"
        local encoded_name
        encoded_name=$(echo "$pool_name" | sed 's|/|%2F|g')
        local response
        response=$(truenas_api_call "GET" "/pool/id/$encoded_name")
    else
        log_info "Getting status for all pools"
        local response
        response=$(truenas_api_call "GET" "/pool")
    fi
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        echo
        if command -v jq >/dev/null 2>&1; then
            echo "$body" | jq .
        else
            echo "$body"
        fi
        return 0
    else
        log_error "Failed to get pool status (HTTP $http_code)"
        log_debug "Response: $body"
        return 1
    fi
}

# Function to list available disks
list_disks() {
    log_info "Fetching available disks..."
    
    local response
    response=$(truenas_api_call "GET" "/disk")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        echo
        printf "%-15s %-15s %-15s %-10s %-15s\n" "DEVICE" "MODEL" "SERIAL" "SIZE" "TYPE"
        printf "%-15s %-15s %-15s %-10s %-15s\n" "------" "-----" "------" "----" "----"
        
        if command -v jq >/dev/null 2>&1; then
            echo "$body" | jq -r '.[] | "\(.name)\t\(.model // "N/A")\t\(.serial // "N/A")\t\(.size // "N/A")\t\(.type // "N/A")"' | \
            while IFS=$'\t' read -r device model serial size type; do
                printf "%-15s %-15s %-15s %-10s %-15s\n" "$device" "$model" "$serial" "$size" "$type"
            done
        else
            # Fallback parsing
            echo "$body" | grep -o '"name": *"[^"]*"' | sed 's/.*"name": *"\([^"]*\)".*/\1/' | \
            while read -r device; do
                printf "%-15s %-15s %-15s %-10s %-15s\n" "$device" "N/A" "N/A" "N/A" "N/A"
            done
        fi
        return 0
    else
        log_error "Failed to get disk list (HTTP $http_code)"
        log_debug "Response: $body"
        return 1
    fi
}

# Function to start pool scrub
start_scrub() {
    local pool_name="${POOL_NAME:-}"
    
    if [ -z "$pool_name" ]; then
        log_error "Pool name is required for scrub command"
        exit 1
    fi

    if [ "$FORCE" = false ]; then
        echo -n "Start scrub on pool '$pool_name'? This may impact performance. [y/N]: "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Scrub cancelled"
            return 0
        fi
    fi
    
    log_info "Starting scrub on pool: $pool_name"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would start scrub on pool: $pool_name"
        return 0
    fi
    
    local response
    response=$(truenas_api_call "POST" "/pool/scrub" "{\"pool\": \"$pool_name\"}")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Scrub started successfully on pool: $pool_name"
        return 0
    else
        log_error "Failed to start scrub (HTTP $http_code)"
        log_debug "Response: $body"
        return 1
    fi
}

# Function to parse topology string
parse_topology() {
    local topology_str="$1"
    local vdevs=()
    
    # Split by spaces to get individual vdev definitions
    IFS=' ' read -ra VDEV_DEFS <<< "$topology_str"
    
    for vdev_def in "${VDEV_DEFS[@]}"; do
        if [[ "$vdev_def" =~ ^(mirror|raidz1|raidz2|raidz3): ]]; then
            # RAID vdev
            local vdev_type="${vdev_def%%:*}"
            local disks="${vdev_def#*:}"
            IFS=',' read -ra DISK_LIST <<< "$disks"
            
            local vdev_json="{\"type\": \"$vdev_type\", \"disks\": ["
            for i, disk in "${!DISK_LIST[@]}"; do
                if [ $i -gt 0 ]; then
                    vdev_json+=", "
                fi
                vdev_json+="\"$disk\""
            done
            vdev_json+="]}"
            vdevs+=("$vdev_json")
        else
            # Stripe (individual disks)
            IFS=',' read -ra DISK_LIST <<< "$vdev_def"
            for disk in "${DISK_LIST[@]}"; do
                vdevs+=("{\"type\": \"stripe\", \"disks\": [\"$disk\"]}")
            done
        fi
    done
    
    # Join vdevs into JSON array
    local topology_json="["
    for i in "${!vdevs[@]}"; do
        if [ $i -gt 0 ]; then
            topology_json+=", "
        fi
        topology_json+="${vdevs[$i]}"
    done
    topology_json+="]"
    
    echo "$topology_json"
}

# Function to build pool configuration from CSV row
build_pool_config() {
    local name="$1"
    local topology="$2"
    local encryption="${3:-false}"
    local compression="${4:-}"
    local atime="${5:-}"
    local checksum="${6:-}"
    local dedup="${7:-}"
    local recordsize="${8:-}"
    
    # Parse topology
    local topology_json
    topology_json=$(parse_topology "$topology")
    
    # Start building JSON
    local json="{\"name\": \"$name\", \"topology\": {\"data\": $topology_json}"
    
    # Handle encryption
    if [ "$encryption" != "false" ] && [ -n "$encryption" ]; then
        json="$json, \"encryption\": true"
        if [[ "$encryption" =~ ^passphrase: ]]; then
            local passphrase="${encryption#passphrase:}"
            json="$json, \"encryption_options\": {\"passphrase\": \"$passphrase\"}"
        else
            json="$json, \"encryption_options\": {\"generate_key\": true}"
        fi
    fi
    
    # Add optional properties
    if [ -n "$compression" ]; then
        json="$json, \"dataset_properties\": {\"compression\": \"$compression\""
        
        [ -n "$atime" ] && json="$json, \"atime\": \"$atime\""
        [ -n "$checksum" ] && json="$json, \"checksum\": \"$checksum\""
        [ -n "$dedup" ] && json="$json, \"deduplication\": \"$dedup\""
        [ -n "$recordsize" ] && json="$json, \"recordsize\": \"$recordsize\""
        
        json="$json}"
    fi
    
    json="$json}"
    echo "$json"
}

# Function to create pools from CSV
create_pools() {
    if [ ! -f "$CSV_FILE" ]; then
        log_error "CSV file not found: $CSV_FILE"
        exit 1
    fi

    # Validate CSV headers
    local header_line
    header_line=$(head -n1 "$CSV_FILE")
    
    if [[ ! "$header_line" =~ "name" ]] || [[ ! "$header_line" =~ "topology" ]]; then
        log_error "CSV file must contain 'name' and 'topology' columns"
        log_info "Current header line: $header_line"
        exit 1
    fi

    local success_count=0
    local error_count=0
    local total_count=0

    # Process each row
    while IFS=',' read -r name topology encryption compression atime checksum dedup recordsize _; do
        # Remove quotes if present
        name=$(echo "$name" | sed 's/^"//; s/"$//')
        topology=$(echo "$topology" | sed 's/^"//; s/"$//')
        
        # Skip empty lines
        [ -z "$name" ] && [ -z "$topology" ] && continue
        
        total_count=$((total_count + 1))
        
        log_info "Processing pool $total_count: $name"
        
        # Build configuration
        local config
        config=$(build_pool_config "$name" "$topology" "$encryption" "$compression" "$atime" "$checksum" "$dedup" "$recordsize")
        
        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would create pool with config:"
            echo "$config" | jq '.' 2>/dev/null || echo "$config"
            success_count=$((success_count + 1))
        else
            local response
            response=$(truenas_api_call "POST" "/pool" "$config")
            
            local http_code="${response: -3}"
            local body="${response%???}"
            
            if [ "$http_code" = "200" ]; then
                log_success "Successfully created pool: $name"
                success_count=$((success_count + 1))
            else
                log_error "Failed to create pool $name (HTTP $http_code)"
                log_debug "Response: $body"
                error_count=$((error_count + 1))
            fi
        fi
        
    done < <(tail -n +2 "$CSV_FILE")

    # Summary
    log_info ""
    log_info "Pool creation summary:"
    log_info "- Successful: $success_count"
    log_info "- Errors: $error_count"
    log_info "- Total processed: $total_count"

    if [ $error_count -gt 0 ]; then
        exit 1
    fi
}

# Function to export pool
export_pool() {
    local pool_name="${POOL_NAME:-}"
    
    if [ -z "$pool_name" ]; then
        log_error "Pool name is required for export command"
        exit 1
    fi

    if [ "$FORCE" = false ]; then
        echo -n "Export pool '$pool_name'? This will make all data inaccessible until reimported. [y/N]: "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Export cancelled"
            return 0
        fi
    fi
    
    log_info "Exporting pool: $pool_name"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would export pool: $pool_name"
        return 0
    fi
    
    local encoded_name
    encoded_name=$(echo "$pool_name" | sed 's|/|%2F|g')
    local response
    response=$(truenas_api_call "POST" "/pool/id/$encoded_name/export" "{}")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Pool exported successfully: $pool_name"
        return 0
    else
        log_error "Failed to export pool (HTTP $http_code)"
        log_debug "Response: $body"
        return 1
    fi
}

# Function to import pools
import_pools() {
    log_info "Scanning for importable pools..."
    
    local response
    response=$(truenas_api_call "GET" "/pool/import_find")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        echo
        log_success "Importable pools found:"
        if command -v jq >/dev/null 2>&1; then
            echo "$body" | jq .
        else
            echo "$body"
        fi
        return 0
    else
        log_error "Failed to find importable pools (HTTP $http_code)"
        log_debug "Response: $body"
        return 1
    fi
}

# Main function
main() {
    echo "TrueNAS Scale Pool Manager"
    echo "========================="
    echo

    parse_args "$@"
    load_config

    if ! test_connection; then
        exit 1
    fi

    case "$COMMAND" in
        list)
            list_pools
            ;;
        status)
            show_pool_status
            ;;
        create)
            create_pools
            ;;
        scrub)
            start_scrub
            ;;
        export)
            export_pool
            ;;
        import)
            import_pools
            ;;
        disks)
            list_disks
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            exit 1
            ;;
    esac
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi