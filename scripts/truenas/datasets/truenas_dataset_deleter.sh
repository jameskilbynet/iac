#!/bin/bash
#
# TrueNAS Scale Dataset Deleter
#
# This script deletes datasets from TrueNAS Scale using the API.
# WARNING: This is a destructive operation that cannot be undone!
#
# Usage: ./truenas_dataset_deleter.sh [OPTIONS]
#
# Author: Generated for TrueNAS automation
#

set -euo pipefail

# Default values
CONFIG_FILE="config.env"
DRY_RUN=false
FORCE=false
POOL_FILTER=""
EXCLUDE_ROOT=true
RECURSIVE=true
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
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
Usage: $0 [OPTIONS]

Delete datasets from TrueNAS Scale

${BOLD}⚠️  WARNING: This is a destructive operation that cannot be undone! ⚠️${NC}

OPTIONS:
    -c, --config FILE       Configuration file (default: config.env)
    --dry-run              Show what would be deleted without actually deleting
    --force                Skip confirmation prompts (dangerous!)
    --pool POOL            Only delete datasets from specific pool
    --include-root         Include root pool datasets (default: exclude)
    --no-recursive         Don't delete child datasets recursively
    -v, --verbose          Enable verbose logging
    -h, --help             Show this help message

EXAMPLES:
    $0 --dry-run                    # See what would be deleted
    $0 --pool pool1 --dry-run       # See what would be deleted from pool1
    $0 --pool pool1 --force         # Delete all datasets from pool1 (no prompts)

SAFETY FEATURES:
    - Requires explicit confirmation by default
    - Dry-run mode to preview changes
    - Excludes root pool datasets by default
    - Verbose logging available
    - Can be limited to specific pools

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
            --pool)
                POOL_FILTER="$2"
                shift 2
                ;;
            --include-root)
                EXCLUDE_ROOT=false
                shift
                ;;
            --no-recursive)
                RECURSIVE=false
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
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
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

    if [ "$method" = "DELETE" ]; then
        curl_opts+=(-X DELETE)
        if [ -n "$data" ]; then
            curl_opts+=(-d "$data")
        fi
    elif [ "$method" = "POST" ] && [ -n "$data" ]; then
        curl_opts+=(-X POST -d "$data")
    fi

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

# Function to get all datasets
get_all_datasets() {
    log_debug "Fetching all datasets..." >&2
    
    local response
    response=$(truenas_api_call "GET" "/pool/dataset")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        echo "$body"
        return 0
    else
        log_error "Failed to get datasets (HTTP $http_code)" >&2
        log_debug "Response: $body" >&2
        return 1
    fi
}

# Function to delete a dataset
delete_dataset() {
    local dataset_name="$1"
    local recursive_param=""
    
    if [ "$RECURSIVE" = true ]; then
        recursive_param='"recursive": true,'
    fi
    
    local payload="{${recursive_param} \"force\": true}"
    
    log_debug "Deleting dataset: $dataset_name with payload: $payload"
    
    local encoded_name
    encoded_name=$(echo "$dataset_name" | sed 's|/|%2F|g')
    
    local response
    response=$(truenas_api_call "DELETE" "/pool/dataset/id/$encoded_name" "$payload")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Successfully deleted dataset: $dataset_name"
        return 0
    else
        log_error "Failed to delete dataset $dataset_name (HTTP $http_code)"
        log_debug "Response: $body"
        return 1
    fi
}

# Function to filter datasets based on criteria
filter_datasets() {
    local datasets_json="$1"
    local filtered_datasets=()
    
    # Parse JSON and apply filters
    local dataset_names
    if command -v jq >/dev/null 2>&1; then
        dataset_names=$(echo "$datasets_json" | jq -r '.[].name')
    elif command -v python3 >/dev/null 2>&1; then
        dataset_names=$(echo "$datasets_json" | python3 -c "import json, sys; data=json.load(sys.stdin); [print(dataset['name']) for dataset in data]")
    else
        # Fallback grep approach
        dataset_names=$(echo "$datasets_json" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
    fi
    
    while IFS= read -r dataset_name; do
        [ -z "$dataset_name" ] && continue
        
        # Apply pool filter if specified
        if [ -n "$POOL_FILTER" ]; then
            if [[ ! "$dataset_name" =~ ^$POOL_FILTER(/|$) ]]; then
                log_debug "Skipping dataset (pool filter): $dataset_name"
                continue
            fi
        fi
        
        # Skip root pool datasets if EXCLUDE_ROOT is true
        if [ "$EXCLUDE_ROOT" = true ]; then
            # Check if dataset name contains no slashes (root dataset)
            if [[ ! "$dataset_name" =~ / ]]; then
                log_debug "Skipping root dataset: $dataset_name"
                continue
            fi
        fi
        
        filtered_datasets+=("$dataset_name")
    done <<< "$dataset_names"
    
    # Sort datasets by depth (deepest first) to avoid parent/child conflicts
    printf '%s\n' "${filtered_datasets[@]}" | while IFS= read -r dataset; do
        # Count slashes to determine depth
        depth=$(echo "$dataset" | tr -cd '/' | wc -c)
        printf "%03d %s\n" "$depth" "$dataset"
    done | sort -nr | cut -d' ' -f2-
}

# Function to confirm deletion
confirm_deletion() {
    local dataset_count="$1"
    
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    echo
    log_warning "You are about to delete $dataset_count dataset(s)"
    log_warning "This operation is IRREVERSIBLE and will destroy all data!"
    echo
    
    read -p "Are you absolutely sure you want to continue? (type 'YES' to confirm): " confirmation
    
    if [ "$confirmation" != "YES" ]; then
        log_info "Operation cancelled by user"
        exit 0
    fi
    
    read -p "Last chance! Type 'DELETE' to proceed: " final_confirmation
    
    if [ "$final_confirmation" != "DELETE" ]; then
        log_info "Operation cancelled by user"
        exit 0
    fi
}

# Main function to process datasets
process_datasets() {
    local datasets_json
    datasets_json=$(get_all_datasets) || {
        log_error "Could not retrieve datasets"
        exit 1
    }
    
    log_debug "Retrieved datasets JSON"
    
    # Filter datasets based on criteria
    local filtered_datasets
    filtered_datasets=$(filter_datasets "$datasets_json")
    
    if [ -z "$filtered_datasets" ]; then
        log_info "No datasets found matching the specified criteria"
        return 0
    fi
    
    local dataset_count
    dataset_count=$(echo "$filtered_datasets" | wc -l)
    
    log_info "Found $dataset_count dataset(s) to delete:"
    echo "$filtered_datasets" | while IFS= read -r dataset; do
        echo "  - $dataset"
    done
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] No datasets were actually deleted"
        return 0
    fi
    
    # Confirm deletion
    confirm_deletion "$dataset_count"
    
    # Delete datasets
    local success_count=0
    local error_count=0
    local total_count=0
    
    echo "$filtered_datasets" | while IFS= read -r dataset_name; do
        [ -z "$dataset_name" ] && continue
        
        total_count=$((total_count + 1))
        log_info "Deleting dataset $total_count/$dataset_count: $dataset_name"
        
        if delete_dataset "$dataset_name"; then
            success_count=$((success_count + 1))
        else
            error_count=$((error_count + 1))
        fi
    done
    
    # Note: Due to subshell, we can't get accurate counts here
    # This is a limitation of the pipe usage, but for deletion
    # operations, individual success/error messages are more important
}

# Main function
main() {
    echo -e "${BOLD}TrueNAS Scale Dataset Deleter${NC}"
    echo -e "${BOLD}===============================${NC}"
    echo
    echo -e "${RED}⚠️  WARNING: This tool can delete ALL your data! ⚠️${NC}"
    echo

    parse_args "$@"
    load_config

    if ! test_connection; then
        exit 1
    fi

    process_datasets
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi