#!/bin/bash
#
# TrueNAS Scale Dataset Creator
#
# This script reads dataset definitions from a CSV file and creates them
# using the TrueNAS Scale API via curl.
#
# Usage: ./truenas_dataset_creator.sh [OPTIONS] <csv_file>
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

Create TrueNAS datasets from CSV input file

OPTIONS:
    -c, --config FILE       Configuration file (default: config.env)
    --dry-run              Show what would be created without actually creating datasets
    --skip-existing        Skip datasets that already exist
    -v, --verbose          Enable verbose logging
    -h, --help             Show this help message

ARGUMENTS:
    csv_file               Path to CSV file containing dataset definitions

EXAMPLE:
    $0 --dry-run datasets.csv
    $0 -c my_config.env --skip-existing datasets.csv

CSV FORMAT:
    Required columns: name, pool
    Optional columns: comments, compression, deduplication, quota, refquota, 
                     reservation, refreservation, recordsize, case_sensitivity, 
                     atime, exec
    
    Child datasets: Use forward slashes in name column for nested datasets
    Example: "applications/web" creates tank/applications/web

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

    if [ "$method" = "POST" ] && [ -n "$data" ]; then
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

# Function to get available pools
get_pools() {
    log_debug "Fetching available storage pools..." >&2
    
    local response
    response=$(truenas_api_call "GET" "/pool")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        echo "$body"
        return 0
    else
        log_error "Failed to get pools (HTTP $http_code)" >&2
        log_debug "Response: $body" >&2
        return 1
    fi
}

# Function to check if dataset exists
dataset_exists() {
    local dataset_name="$1"
    local encoded_name
    encoded_name=$(echo "$dataset_name" | sed 's|/|%2F|g')
    
    log_debug "Checking if dataset exists: $dataset_name"
    
    local response
    response=$(truenas_api_call "GET" "/pool/dataset/id/$encoded_name")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        return 0  # Dataset exists
    else
        return 1  # Dataset doesn't exist
    fi
}

# Function to create a dataset
create_dataset() {
    local config="$1"
    local dataset_name
    dataset_name=$(echo "$config" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
    
    log_debug "Creating dataset with config: $config"
    
    local response
    response=$(truenas_api_call "POST" "/pool/dataset" "$config")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Successfully created dataset: $dataset_name"
        return 0
    else
        log_error "Failed to create dataset $dataset_name (HTTP $http_code)"
        log_debug "Response: $body"
        return 1
    fi
}

# Function to get parent dataset path
get_parent_path() {
    local dataset_path="$1"
    local parent_path
    
    # If path contains '/', get everything before the last '/'
    if [[ "$dataset_path" =~ / ]]; then
        parent_path="${dataset_path%/*}"
        echo "$parent_path"
    else
        # No parent (top-level dataset)
        echo ""
    fi
}

# Function to get all parent paths for a dataset
get_all_parent_paths() {
    local dataset_path="$1"
    local parents=()
    local current_path="$dataset_path"
    
    while true; do
        local parent
        parent=$(get_parent_path "$current_path")
        
        if [ -z "$parent" ]; then
            break
        fi
        
        if [ ${#parents[@]} -gt 0 ]; then
            parents=("$parent" "${parents[@]}")
        else
            parents=("$parent")
        fi
        current_path="$parent"
    done
    
    if [ ${#parents[@]} -gt 0 ]; then
        printf '%s\n' "${parents[@]}"
    fi
}

# Function to create parent datasets if they don't exist
ensure_parent_datasets() {
    local dataset_path="$1"
    local pool_names="$2"
    
    local parents
    parents=$(get_all_parent_paths "$dataset_path")
    
    if [ -z "$parents" ]; then
        return 0  # No parents needed
    fi
    
    echo "$parents" | while read -r parent_path; do
        if [ -z "$parent_path" ]; then
            continue
        fi
        
        # Extract pool and name from parent path
        local pool="${parent_path%%/*}"
        local name="${parent_path#*/}"
        
        # Validate pool exists
        if ! echo "$pool_names" | grep -q "^$pool$"; then
            log_error "Pool '$pool' does not exist for parent dataset: $parent_path"
            return 1
        fi
        
        # Check if parent already exists
        if dataset_exists "$parent_path"; then
            log_debug "Parent dataset already exists: $parent_path"
            continue
        fi
        
        log_info "Creating parent dataset: $parent_path"
        
        # Create basic parent dataset configuration
        local parent_config
        parent_config=$(build_dataset_config "$name" "$pool")
        
        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would create parent dataset: $parent_path"
        else
            if ! create_dataset "$parent_config"; then
                log_error "Failed to create parent dataset: $parent_path"
                return 1
            fi
        fi
    done
}

# Function to build JSON configuration from CSV row
build_dataset_config() {
    local name="$1"
    local pool="$2"
    local comments="${3:-}"
    local compression="${4:-}"
    local deduplication="${5:-}"
    local quota="${6:-}"
    local refquota="${7:-}"
    local reservation="${8:-}"
    local refreservation="${9:-}"
    local recordsize="${10:-}"
    local case_sensitivity="${11:-}"
    local atime="${12:-}"
    local exec="${13:-}"

    # Handle child datasets - name can contain slashes for nested paths
    local full_path
    if [[ "$name" =~ ^/ ]]; then
        # Name starts with slash, treat as absolute path from pool root
        full_path="$pool${name}"
    elif [[ "$name" =~ / ]]; then
        # Name contains slashes, treat as relative path
        full_path="$pool/$name"
    else
        # Simple name, direct child of pool
        full_path="$pool/$name"
    fi

    # Start building JSON
    local json="{\"name\":\"$full_path\",\"type\":\"FILESYSTEM\""

    # Add optional fields if they exist
    [ -n "$comments" ] && json="$json,\"comments\":\"$comments\""
    [ -n "$compression" ] && json="$json,\"compression\":\"$(echo "$compression" | tr '[:lower:]' '[:upper:]')\""
    [ -n "$deduplication" ] && json="$json,\"deduplication\":\"$(echo "$deduplication" | tr '[:lower:]' '[:upper:]')\""
    [ -n "$recordsize" ] && json="$json,\"recordsize\":\"$recordsize\""
    [ -n "$case_sensitivity" ] && json="$json,\"casesensitivity\":\"$(echo "$case_sensitivity" | tr '[:lower:]' '[:upper:]')\""

    # Handle numeric fields
    if [ -n "$quota" ] && [ "$quota" != "NONE" ] && [ "$quota" != "none" ]; then
        json="$json,\"quota\":$quota"
    fi
    if [ -n "$refquota" ] && [ "$refquota" != "NONE" ] && [ "$refquota" != "none" ]; then
        json="$json,\"refquota\":$refquota"
    fi
    if [ -n "$reservation" ] && [ "$reservation" != "NONE" ] && [ "$reservation" != "none" ]; then
        json="$json,\"reservation\":$reservation"
    fi
    if [ -n "$refreservation" ] && [ "$refreservation" != "NONE" ] && [ "$refreservation" != "none" ]; then
        json="$json,\"refreservation\":$refreservation"
    fi

    # Handle boolean fields (convert to string format)
    if [ -n "$atime" ]; then
        if [ "$atime" = "ON" ] || [ "$atime" = "on" ] || [ "$atime" = "true" ]; then
            json="$json,\"atime\":\"ON\""
        else
            json="$json,\"atime\":\"OFF\""
        fi
    fi
    if [ -n "$exec" ]; then
        if [ "$exec" = "ON" ] || [ "$exec" = "on" ] || [ "$exec" = "true" ]; then
            json="$json,\"exec\":\"ON\""
        else
            json="$json,\"exec\":\"OFF\""
        fi
    fi

    json="$json}"
    echo "$json"
}

# Function to validate CSV file
validate_csv_file() {
    if [ ! -f "$CSV_FILE" ]; then
        log_error "CSV file not found: $CSV_FILE"
        exit 1
    fi

    # Check if file has headers
    local header_line
    header_line=$(head -n1 "$CSV_FILE")
    
    if [[ ! "$header_line" =~ "name" ]] || [[ ! "$header_line" =~ "pool" ]]; then
        log_error "CSV file must contain 'name' and 'pool' columns"
        log_info "Current header line: $header_line"
        exit 1
    fi

    log_success "CSV file validation passed"
}

# Function to sort datasets by hierarchy (parents first)
sort_datasets_by_hierarchy() {
    local csv_file="$1"
    local temp_file
    temp_file=$(mktemp)
    
    # Read CSV and sort by dataset depth (number of slashes in name)
    {
        head -n1 "$csv_file"  # Keep header
        tail -n +2 "$csv_file" | while IFS=',' read -r name pool rest; do
            # Remove quotes from name
            clean_name=$(echo "$name" | sed 's/^"//; s/"$//')
            # Count slashes to determine depth
            depth=$(echo "$clean_name" | tr -cd '/' | wc -c)
            # Output with depth prefix for sorting
            printf "%03d,%s,%s,%s\n" "$depth" "$name" "$pool" "$rest"
        done | sort -n | cut -d',' -f2-  # Sort by depth, then remove depth prefix
    } > "$temp_file"
    
    echo "$temp_file"
}

# Function to process CSV file
process_csv_file() {
    local pools_json
    pools_json=$(get_pools) || {
        log_error "Could not retrieve storage pools"
        exit 1
    }

    # Extract pool names from JSON (use jq if available, fallback to python3)
    local pool_names
    if command -v jq >/dev/null 2>&1; then
        pool_names=$(echo "$pools_json" | jq -r '.[].name' 2>/dev/null) || {
            if command -v python3 >/dev/null 2>&1; then
                pool_names=$(echo "$pools_json" | python3 -c "import json, sys; data=json.load(sys.stdin); [print(pool['name']) for pool in data]" 2>/dev/null)
            else
                # Fallback grep approach for formatted JSON
                pool_names=$(echo "$pools_json" | grep -A1 -B1 '"id":' | grep -o '"name": *"[^"]*"' | sed 's/.*"name": *"\([^"]*\)".*/\1/')
            fi
        }
    elif command -v python3 >/dev/null 2>&1; then
        pool_names=$(echo "$pools_json" | python3 -c "import json, sys; data=json.load(sys.stdin); [print(pool['name']) for pool in data]")
    else
        # Fallback grep approach for formatted JSON
        pool_names=$(echo "$pools_json" | grep -A1 -B1 '"id":' | grep -o '"name": *"[^"]*"' | sed 's/.*"name": *"\([^"]*\)".*/\1/')
    fi
    log_info "Available pools: $(echo "$pool_names" | tr '\n' ' ')"

    # Sort datasets by hierarchy to ensure parents are created first
    local sorted_csv
    sorted_csv=$(sort_datasets_by_hierarchy "$CSV_FILE")
    log_debug "Using hierarchically sorted dataset list"

    local success_count=0
    local error_count=0
    local skipped_count=0
    local total_count=0

    # Skip header line and process each data row in hierarchical order
    while IFS=',' read -r name pool comments compression deduplication quota refquota reservation refreservation recordsize case_sensitivity atime exec _; do
        # Remove quotes if present
        name=$(echo "$name" | sed 's/^"//; s/"$//')
        pool=$(echo "$pool" | sed 's/^"//; s/"$//')
        
        # Skip empty lines
        [ -z "$name" ] && [ -z "$pool" ] && continue
        
        total_count=$((total_count + 1))
        
        # Build full dataset path
        local dataset_name
        if [[ "$name" =~ ^/ ]]; then
            dataset_name="$pool${name}"
        elif [[ "$name" =~ / ]]; then
            dataset_name="$pool/$name"
        else
            dataset_name="$pool/$name"
        fi
        
        log_info "Processing dataset $total_count: $dataset_name"

        # Extract base pool name for validation
        local base_pool="${dataset_name%%/*}"
        if ! echo "$pool_names" | grep -q "^$base_pool$"; then
            log_error "Pool '$base_pool' does not exist. Skipping dataset: $dataset_name"
            error_count=$((error_count + 1))
            continue
        fi

        # Check if dataset already exists
        if [ "$SKIP_EXISTING" = true ] && dataset_exists "$dataset_name"; then
            log_warning "Dataset already exists, skipping: $dataset_name"
            skipped_count=$((skipped_count + 1))
            continue
        fi

        # Ensure parent datasets exist
        if ! ensure_parent_datasets "$dataset_name" "$pool_names"; then
            log_error "Failed to ensure parent datasets for: $dataset_name"
            error_count=$((error_count + 1))
            continue
        fi

        # Build configuration
        local config
        config=$(build_dataset_config "$name" "$pool" "$comments" "$compression" "$deduplication" "$quota" "$refquota" "$reservation" "$refreservation" "$recordsize" "$case_sensitivity" "$atime" "$exec")

        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY RUN] Would create dataset with config:"
            echo "$config" | jq '.' 2>/dev/null || echo "$config"
            success_count=$((success_count + 1))
        else
            if create_dataset "$config"; then
                success_count=$((success_count + 1))
            else
                error_count=$((error_count + 1))
            fi
        fi
    done < <(tail -n +2 "$sorted_csv")

    # Clean up temporary file
    [ -f "$sorted_csv" ] && rm -f "$sorted_csv"

    # Summary (this runs in subshell, so we'll handle it differently)
    log_info ""
    log_info "Dataset creation summary:"
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
    echo "TrueNAS Scale Dataset Creator"
    echo "============================="
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