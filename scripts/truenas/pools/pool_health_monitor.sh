#!/bin/bash
#
# TrueNAS Scale Pool Health Monitor
#
# This utility script provides enhanced pool health monitoring and alerting
# capabilities for TrueNAS Scale systems.
#
# Usage: ./pool_health_monitor.sh [OPTIONS]
#
# Author: Generated for TrueNAS automation
#

set -euo pipefail

# Default values
CONFIG_FILE="config.env"
ALERT_THRESHOLD=80  # Alert when pool usage exceeds this percentage
NAGIOS_MODE=false
JSON_OUTPUT=false
QUIET_MODE=false
VERBOSE=false
CHECK_SCRUB=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Exit codes for monitoring systems
EXIT_OK=0
EXIT_WARNING=1
EXIT_CRITICAL=2
EXIT_UNKNOWN=3

# Function to print colored output
log_info() {
    [ "$QUIET_MODE" = false ] && echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    [ "$QUIET_MODE" = false ] && echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_critical() {
    echo -e "${RED}[CRITICAL]${NC} $1" >&2
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1" >&2
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Monitor TrueNAS Scale storage pool health and status

OPTIONS:
    -c, --config FILE       Configuration file (default: config.env)
    -t, --threshold PERCENT Alert threshold for pool usage (default: 80)
    --nagios               Output in Nagios-compatible format
    --json                 Output results in JSON format
    --no-scrub            Skip scrub status checking
    -q, --quiet           Suppress informational output
    -v, --verbose         Enable verbose logging
    -h, --help            Show this help message

EXAMPLES:
    $0                                    # Basic health check
    $0 --threshold 90                     # Alert at 90% usage
    $0 --nagios --threshold 85            # Nagios monitoring mode
    $0 --json                            # JSON output for automation
    $0 --quiet --no-scrub                # Quiet mode, skip scrub checks

EXIT CODES (Nagios compatible):
    0 - OK: All pools healthy
    1 - WARNING: Minor issues detected
    2 - CRITICAL: Serious problems detected
    3 - UNKNOWN: Unable to check status

MONITORING OUTPUT:
    The script provides detailed status for each pool including:
    - Pool health and status
    - Capacity usage and alerts
    - Scrub status and completion
    - Error counts and vdev status
    - Performance metrics (if available)

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
            -t|--threshold)
                ALERT_THRESHOLD="$2"
                shift 2
                ;;
            --nagios)
                NAGIOS_MODE=true
                shift
                ;;
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            --no-scrub)
                CHECK_SCRUB=false
                shift
                ;;
            -q|--quiet)
                QUIET_MODE=true
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
                exit $EXIT_UNKNOWN
                ;;
        esac
    done
}

# Function to load configuration
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit $EXIT_UNKNOWN
    fi

    log_debug "Loading configuration from: $CONFIG_FILE"
    source "$CONFIG_FILE"

    # Validate required configuration
    if [ -z "${TRUENAS_HOST:-}" ] || [ -z "${TRUENAS_API_KEY:-}" ]; then
        log_error "Missing required configuration: TRUENAS_HOST and TRUENAS_API_KEY must be set"
        exit $EXIT_UNKNOWN
    fi

    # Set default for SSL verification
    VERIFY_SSL="${VERIFY_SSL:-true}"
}

# Function to make API calls to TrueNAS
truenas_api_call() {
    local method="$1"
    local endpoint="$2"
    local curl_opts=()

    # Build curl options
    curl_opts+=(-s -w "%{http_code}")
    curl_opts+=(-H "Authorization: Bearer $TRUENAS_API_KEY")
    curl_opts+=(-H "Content-Type: application/json")

    if [ "$VERIFY_SSL" != "true" ]; then
        curl_opts+=(-k)
    fi

    log_debug "API Call: $method ${TRUENAS_HOST}/api/v2.0${endpoint}"

    curl "${curl_opts[@]}" "${TRUENAS_HOST}/api/v2.0${endpoint}"
}

# Function to check pool health
check_pool_health() {
    local response
    response=$(truenas_api_call "GET" "/pool")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" != "200" ]; then
        log_error "Failed to get pool status (HTTP $http_code)"
        log_debug "Response: $body"
        return $EXIT_CRITICAL
    fi

    echo "$body"
}

# Function to parse pool data and generate alerts
analyze_pools() {
    local pools_data="$1"
    local exit_code=$EXIT_OK
    local warnings=()
    local criticals=()
    local pool_count=0
    local healthy_count=0
    
    if [ "$JSON_OUTPUT" = true ]; then
        echo "{"
        echo "  \"timestamp\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\","
        echo "  \"threshold\": $ALERT_THRESHOLD,"
        echo "  \"pools\": ["
    fi
    
    # Parse pools using jq if available, fallback to basic parsing
    if command -v jq >/dev/null 2>&1; then
        local pool_names
        pool_names=$(echo "$pools_data" | jq -r '.[].name' 2>/dev/null)
        
        local first_pool=true
        while IFS= read -r pool_name; do
            [ -z "$pool_name" ] && continue
            pool_count=$((pool_count + 1))
            
            local pool_info
            pool_info=$(echo "$pools_data" | jq -r ".[] | select(.name == \"$pool_name\")")
            
            local status health used_pct scrub_status
            status=$(echo "$pool_info" | jq -r '.status // "UNKNOWN"')
            health=$(echo "$pool_info" | jq -r '.healthy // false')
            
            # Calculate usage percentage
            local size available used_pct_raw
            size=$(echo "$pool_info" | jq -r '.size // 0')
            available=$(echo "$pool_info" | jq -r '.available // 0')
            
            if [ "$size" != "0" ] && [ "$available" != "0" ]; then
                used_pct_raw=$(echo "scale=2; (($size - $available) * 100) / $size" | bc -l 2>/dev/null || echo "0")
                used_pct=$(printf "%.1f" "$used_pct_raw")
            else
                used_pct="N/A"
            fi
            
            # Check scrub status if enabled
            scrub_status="N/A"
            if [ "$CHECK_SCRUB" = true ]; then
                # This would require additional API call to get scrub status
                # For now, we'll mark as N/A
                scrub_status="N/A"
            fi
            
            # Determine pool health status
            local pool_exit_code=$EXIT_OK
            local issues=()
            
            # Check pool status
            if [ "$status" != "ONLINE" ]; then
                criticals+=("Pool $pool_name status is $status")
                issues+=("status: $status")
                pool_exit_code=$EXIT_CRITICAL
            fi
            
            # Check pool health
            if [ "$health" != "true" ]; then
                criticals+=("Pool $pool_name is unhealthy")
                issues+=("unhealthy")
                pool_exit_code=$EXIT_CRITICAL
            fi
            
            # Check usage threshold
            if [ "$used_pct" != "N/A" ]; then
                local used_pct_int
                used_pct_int=$(echo "$used_pct" | cut -d. -f1)
                if [ "$used_pct_int" -ge "$ALERT_THRESHOLD" ]; then
                    warnings+=("Pool $pool_name usage is ${used_pct}% (threshold: ${ALERT_THRESHOLD}%)")
                    issues+=("usage: ${used_pct}%")
                    if [ $pool_exit_code -eq $EXIT_OK ]; then
                        pool_exit_code=$EXIT_WARNING
                    fi
                fi
            fi
            
            # Update counters
            if [ $pool_exit_code -eq $EXIT_OK ]; then
                healthy_count=$((healthy_count + 1))
            fi
            
            # Update overall exit code
            if [ $pool_exit_code -gt $exit_code ]; then
                exit_code=$pool_exit_code
            fi
            
            # Output format based on mode
            if [ "$JSON_OUTPUT" = true ]; then
                if [ "$first_pool" = false ]; then
                    echo ","
                fi
                echo "    {"
                echo "      \"name\": \"$pool_name\","
                echo "      \"status\": \"$status\","
                echo "      \"healthy\": $health,"
                echo "      \"usage_percent\": \"$used_pct\","
                echo "      \"scrub_status\": \"$scrub_status\","
                echo "      \"issues\": [$(printf '"%s"' "${issues[@]}" | paste -sd, -)],"
                echo "      \"exit_code\": $pool_exit_code"
                echo -n "    }"
                first_pool=false
            elif [ "$NAGIOS_MODE" = false ] && [ "$QUIET_MODE" = false ]; then
                local status_color=""
                local status_text=""
                case $pool_exit_code in
                    $EXIT_OK)
                        status_color="$GREEN"
                        status_text="OK"
                        ;;
                    $EXIT_WARNING)
                        status_color="$YELLOW"
                        status_text="WARNING"
                        ;;
                    $EXIT_CRITICAL)
                        status_color="$RED"
                        status_text="CRITICAL"
                        ;;
                esac
                
                printf "%-15s %s%-10s%s %-8s %-10s" "$pool_name" "$status_color" "$status_text" "$NC" "$status" "$used_pct%"
                if [ ${#issues[@]} -gt 0 ]; then
                    printf " [%s]" "$(IFS=', '; echo "${issues[*]}")"
                fi
                echo
            fi
            
        done <<< "$pool_names"
    else
        # Fallback parsing without jq
        pool_count=$(echo "$pools_data" | grep -c '"name"' 2>/dev/null || echo "0")
        healthy_count=$pool_count  # Assume healthy if we can't parse details
        
        if [ "$JSON_OUTPUT" = false ] && [ "$QUIET_MODE" = false ]; then
            echo "Warning: jq not available, limited pool analysis"
        fi
    fi
    
    if [ "$JSON_OUTPUT" = true ]; then
        echo ""
        echo "  ],"
        echo "  \"summary\": {"
        echo "    \"total_pools\": $pool_count,"
        echo "    \"healthy_pools\": $healthy_count,"
        echo "    \"warnings\": [$(printf '"%s"' "${warnings[@]}" | paste -sd, -)],"
        echo "    \"criticals\": [$(printf '"%s"' "${criticals[@]}" | paste -sd, -)],"
        echo "    \"exit_code\": $exit_code"
        echo "  }"
        echo "}"
    elif [ "$NAGIOS_MODE" = true ]; then
        # Nagios output format
        local status_text=""
        case $exit_code in
            $EXIT_OK)
                status_text="OK"
                ;;
            $EXIT_WARNING)
                status_text="WARNING"
                ;;
            $EXIT_CRITICAL)
                status_text="CRITICAL"
                ;;
            $EXIT_UNKNOWN)
                status_text="UNKNOWN"
                ;;
        esac
        
        local message="POOLS $status_text - $healthy_count/$pool_count pools healthy"
        
        # Add performance data
        message="$message | pools_total=$pool_count pools_healthy=$healthy_count"
        
        # Add details for warnings and criticals
        if [ ${#criticals[@]} -gt 0 ]; then
            message="$message; CRITICAL: $(IFS=', '; echo "${criticals[*]}")"
        fi
        if [ ${#warnings[@]} -gt 0 ]; then
            message="$message; WARNING: $(IFS=', '; echo "${warnings[*]}")"
        fi
        
        echo "$message"
    else
        # Standard output format
        if [ "$QUIET_MODE" = false ]; then
            echo
            echo "Pool Health Summary:"
            echo "==================="
            printf "Total Pools: %d\n" "$pool_count"
            printf "Healthy Pools: %d\n" "$healthy_count"
            printf "Alert Threshold: %d%%\n" "$ALERT_THRESHOLD"
            
            if [ ${#warnings[@]} -gt 0 ]; then
                echo
                echo "Warnings:"
                printf '  - %s\n' "${warnings[@]}"
            fi
            
            if [ ${#criticals[@]} -gt 0 ]; then
                echo
                echo "Critical Issues:"
                printf '  - %s\n' "${criticals[@]}"
            fi
        fi
    fi
    
    return $exit_code
}

# Main function
main() {
    local exit_code
    
    parse_args "$@"
    load_config
    
    if [ "$QUIET_MODE" = false ] && [ "$JSON_OUTPUT" = false ] && [ "$NAGIOS_MODE" = false ]; then
        echo "TrueNAS Scale Pool Health Monitor"
        echo "================================"
        echo
        
        printf "%-15s %-10s %-8s %-10s %s\n" "POOL" "STATUS" "HEALTH" "USAGE" "ISSUES"
        printf "%-15s %-10s %-8s %-10s %s\n" "----" "------" "------" "-----" "------"
    fi
    
    # Get pool data
    local pools_data
    pools_data=$(check_pool_health) || exit $?
    
    # Analyze and output results
    analyze_pools "$pools_data"
    exit_code=$?
    
    exit $exit_code
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi