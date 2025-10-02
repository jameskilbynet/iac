#!/bin/bash

#################################################################
# MikroTik VCF Configuration Validation Script
# 
# This script validates that a MikroTik switch is properly
# configured for VMware VCF environment
#################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default configuration file
CONFIG_FILE="${SCRIPT_DIR}/vcf-config.env"

# Validation results
PASSED=0
FAILED=0
WARNINGS=0

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

# Function to execute RouterOS command and return output
execute_ros_command() {
    local command="$1"
    
    if ! sshpass -p "$MIKROTIK_PASSWORD" ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 \
        "$MIKROTIK_USER@$MIKROTIK_IP" "$command" 2>/dev/null; then
        return 1
    fi
}

# Function to load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        print_status "Configuration loaded from: $CONFIG_FILE"
    else
        print_warning "Configuration file not found: $CONFIG_FILE"
        print_status "Using default values where possible"
        
        # Set defaults
        MIKROTIK_IP="${MIKROTIK_IP:-192.168.1.1}"
        MIKROTIK_USER="${MIKROTIK_USER:-admin}"
        BRIDGE_NAME="${BRIDGE_NAME:-br-vcf}"
        MGMT_VLAN_ID="${MGMT_VLAN_ID:-100}"
        VMOTION_VLAN_ID="${VMOTION_VLAN_ID:-101}"
        VSAN_VLAN_ID="${VSAN_VLAN_ID:-102}"
        TEP_VLAN_ID="${TEP_VLAN_ID:-103}"
    fi
}

# Function to validate bridge configuration
validate_bridge() {
    print_status "Validating bridge configuration..."
    
    # Check if bridge exists
    if execute_ros_command "/interface bridge print where name=$BRIDGE_NAME" | grep -q "$BRIDGE_NAME"; then
        print_success "Bridge $BRIDGE_NAME exists"
        
        # Check VLAN filtering
        if execute_ros_command "/interface bridge print where name=$BRIDGE_NAME" | grep -q "vlan-filtering=yes"; then
            print_success "VLAN filtering is enabled on bridge"
        else
            print_error "VLAN filtering is not enabled on bridge"
        fi
    else
        print_error "Bridge $BRIDGE_NAME not found"
    fi
}

# Function to validate VLAN configuration
validate_vlans() {
    print_status "Validating VLAN configuration..."
    
    local required_vlans=(
        "$MGMT_VLAN_ID:Management"
        "$VMOTION_VLAN_ID:vMotion"
        "$VSAN_VLAN_ID:vSAN"
        "$TEP_VLAN_ID:NSX-TEP"
    )
    
    # Add optional VLANs if configured
    [[ -n "${EDGE_TEP_VLAN_ID:-}" ]] && required_vlans+=("$EDGE_TEP_VLAN_ID:NSX-Edge-TEP")
    [[ -n "${VM_VLAN_ID:-}" ]] && required_vlans+=("$VM_VLAN_ID:VM-Network")
    [[ -n "${NFS_VLAN_ID:-}" ]] && required_vlans+=("$NFS_VLAN_ID:NFS-Storage")
    
    for vlan_config in "${required_vlans[@]}"; do
        IFS=':' read -r vlan_id vlan_name <<< "$vlan_config"
        
        # Check VLAN interface
        if execute_ros_command "/interface vlan print where vlan-id=$vlan_id" | grep -q "vlan$vlan_id"; then
            print_success "VLAN $vlan_id ($vlan_name) interface exists"
        else
            print_error "VLAN $vlan_id ($vlan_name) interface not found"
        fi
        
        # Check bridge VLAN configuration
        if execute_ros_command "/interface bridge vlan print where vlan-ids=$vlan_id" | grep -q "$vlan_id"; then
            print_success "Bridge VLAN configuration for VLAN $vlan_id exists"
        else
            print_error "Bridge VLAN configuration for VLAN $vlan_id not found"
        fi
    done
}

# Function to validate IP addressing
validate_ip_addressing() {
    print_status "Validating IP addressing..."
    
    local required_vlans=(
        "$MGMT_VLAN_ID"
        "$VMOTION_VLAN_ID"
        "$VSAN_VLAN_ID"
        "$TEP_VLAN_ID"
    )
    
    # Add optional VLANs if configured
    [[ -n "${EDGE_TEP_VLAN_ID:-}" ]] && required_vlans+=("$EDGE_TEP_VLAN_ID")
    [[ -n "${VM_VLAN_ID:-}" ]] && required_vlans+=("$VM_VLAN_ID")
    [[ -n "${NFS_VLAN_ID:-}" ]] && required_vlans+=("$NFS_VLAN_ID")
    
    for vlan_id in "${required_vlans[@]}"; do
        if execute_ros_command "/ip address print where interface=vlan$vlan_id" | grep -q "vlan$vlan_id"; then
            print_success "IP address configured for VLAN $vlan_id"
        else
            print_warning "No IP address configured for VLAN $vlan_id"
        fi
    done
}

# Function to validate bridge ports
validate_bridge_ports() {
    print_status "Validating bridge ports..."
    
    local port_count
    port_count=$(execute_ros_command "/interface bridge port print where bridge=$BRIDGE_NAME" | grep -c "$BRIDGE_NAME" || echo "0")
    
    if [[ $port_count -gt 0 ]]; then
        print_success "$port_count ports configured on bridge $BRIDGE_NAME"
    else
        print_error "No ports configured on bridge $BRIDGE_NAME"
    fi
    
    # Check for uplink configuration (tagged ports)
    local tagged_count
    tagged_count=$(execute_ros_command "/interface bridge vlan print" | grep -c "tagged=" || echo "0")
    
    if [[ $tagged_count -gt 0 ]]; then
        print_success "Tagged VLAN configuration found"
    else
        print_warning "No tagged VLAN ports found - check uplink configuration"
    fi
}

# Function to validate routing
validate_routing() {
    print_status "Validating routing configuration..."
    
    # Check for default route
    if execute_ros_command "/ip route print where dst-address=0.0.0.0/0" | grep -q "0.0.0.0/0"; then
        print_success "Default route configured"
    else
        print_warning "No default route found"
    fi
    
    # Check IP forwarding
    if execute_ros_command "/ip settings print" | grep -q "ip-forward=yes"; then
        print_success "IP forwarding is enabled"
    else
        print_error "IP forwarding is not enabled"
    fi
}

# Function to validate security settings
validate_security() {
    print_status "Validating security configuration..."
    
    # Check disabled services
    local disabled_services=("telnet" "ftp" "www")
    
    for service in "${disabled_services[@]}"; do
        if execute_ros_command "/ip service print where name=$service" | grep -q "disabled=yes"; then
            print_success "Service $service is disabled"
        else
            print_warning "Service $service is not disabled"
        fi
    done
    
    # Check enabled services
    local enabled_services=("ssh" "www-ssl" "api" "api-ssl")
    
    for service in "${enabled_services[@]}"; do
        if execute_ros_command "/ip service print where name=$service" | grep -q "disabled=no"; then
            print_success "Service $service is enabled"
        else
            print_error "Service $service is not enabled"
        fi
    done
}

# Function to validate system configuration
validate_system() {
    print_status "Validating system configuration..."
    
    # Check system identity
    local identity
    identity=$(execute_ros_command "/system identity print" | grep "name:" | cut -d' ' -f2- || echo "unknown")
    
    if [[ "$identity" != "MikroTik" ]]; then
        print_success "System identity set to: $identity"
    else
        print_warning "System identity is still default (MikroTik)"
    fi
    
    # Check NTP client
    if execute_ros_command "/system ntp client print" | grep -q "enabled=yes"; then
        print_success "NTP client is enabled"
    else
        print_warning "NTP client is not enabled"
    fi
    
    # Check DNS configuration
    if execute_ros_command "/ip dns print" | grep -q "servers="; then
        print_success "DNS servers configured"
    else
        print_warning "No DNS servers configured"
    fi
}

# Function to validate connectivity
validate_connectivity() {
    print_status "Validating basic connectivity..."
    
    local test_addresses=(
        "${MANAGEMENT_GATEWAY:-192.168.100.1}"
    )
    
    for addr in "${test_addresses[@]}"; do
        if execute_ros_command "/ping $addr count=3" | grep -q "sent=3 received=3"; then
            print_success "Connectivity to $addr: OK"
        else
            print_warning "Connectivity to $addr: FAILED"
        fi
    done
}

# Function to show validation summary
show_summary() {
    echo
    echo "=============================================="
    echo "         VALIDATION SUMMARY"
    echo "=============================================="
    echo
    print_status "Total Tests: $((PASSED + FAILED + WARNINGS))"
    echo -e "${GREEN}Passed: $PASSED${NC}"
    echo -e "${RED}Failed: $FAILED${NC}"
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    echo
    
    if [[ $FAILED -eq 0 ]]; then
        print_success "All critical tests passed!"
        if [[ $WARNINGS -gt 0 ]]; then
            print_warning "Some warnings were found - review configuration"
        fi
    else
        print_error "$FAILED critical issues found - review configuration"
        return 1
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -c, --config FILE       Configuration file (default: ./vcf-config.env)
    -i, --ip ADDRESS        MikroTik IP address
    -u, --username USER     MikroTik username (default: admin)
    -p, --password PASS     MikroTik password
    --quick                 Run quick validation (skip connectivity tests)

EXAMPLES:
    $0                                          # Use config file
    $0 -i 192.168.1.1 -u admin -p password    # Direct connection
    $0 --quick                                 # Quick validation

EOF
}

# Main function
main() {
    local quick_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -i|--ip)
                MIKROTIK_IP="$2"
                shift 2
                ;;
            -u|--username)
                MIKROTIK_USER="$2"
                shift 2
                ;;
            -p|--password)
                MIKROTIK_PASSWORD="$2"
                shift 2
                ;;
            --quick)
                quick_mode=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    print_status "MikroTik VCF Configuration Validation Starting..."
    
    # Load configuration
    load_config
    
    # Set defaults if not provided
    MIKROTIK_USER="${MIKROTIK_USER:-admin}"
    
    # Prompt for password if not provided
    if [[ -z "${MIKROTIK_PASSWORD:-}" ]]; then
        read -s -p "Enter MikroTik password: " MIKROTIK_PASSWORD
        echo
    fi
    
    # Test connection
    print_status "Testing connection to $MIKROTIK_IP..."
    if ! execute_ros_command "/system identity print" &>/dev/null; then
        print_error "Cannot connect to MikroTik at $MIKROTIK_IP"
        exit 1
    fi
    print_success "Connection successful"
    
    # Run validation tests
    validate_system
    validate_bridge
    validate_vlans
    validate_ip_addressing
    validate_bridge_ports
    validate_routing
    validate_security
    
    # Run connectivity tests unless quick mode
    if [[ "$quick_mode" == "false" ]]; then
        validate_connectivity
    fi
    
    # Show summary
    show_summary
}

# Execute main function
main "$@"