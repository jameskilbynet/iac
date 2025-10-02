#!/bin/bash

#################################################################
# MikroTik Switch Provisioning Script for VMware VCF Environment
# 
# This script provisions a MikroTik switch for VMware Cloud Foundation
# with the necessary VLANs, bridge configuration, and network settings
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

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
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
    --dry-run              Show commands without executing
    --generate-config      Generate sample configuration file

EXAMPLES:
    $0 --generate-config                    # Generate sample config
    $0 -i 192.168.1.1 -u admin -p password # Quick provision
    $0 -c my-vcf.env                       # Use custom config

EOF
}

# Function to generate sample configuration
generate_config() {
    cat > "$CONFIG_FILE" << 'EOF'
# MikroTik Configuration for VMware VCF
# Copy this file and customize for your environment

# MikroTik Connection Settings
MIKROTIK_IP="192.168.1.1"
MIKROTIK_USER="admin"
MIKROTIK_PASSWORD=""

# Basic Network Configuration
MANAGEMENT_INTERFACE="ether1"
MANAGEMENT_IP="192.168.100.10/24"
MANAGEMENT_GATEWAY="192.168.100.1"

# VCF Network Configuration
# Management Network (for ESXi management, vCenter, NSX managers)
MGMT_VLAN_ID="100"
MGMT_NETWORK="192.168.100.0/24"

# vMotion Network
VMOTION_VLAN_ID="101"
VMOTION_NETWORK="192.168.101.0/24"

# vSAN Network
VSAN_VLAN_ID="102"
VSAN_NETWORK="192.168.102.0/24"

# NSX TEP (Tunnel Endpoint) Network
TEP_VLAN_ID="103"
TEP_NETWORK="192.168.103.0/24"

# NSX Edge TEP Network
EDGE_TEP_VLAN_ID="104"
EDGE_TEP_NETWORK="192.168.104.0/24"

# VM Network (for VCF VMs)
VM_VLAN_ID="105"
VM_NETWORK="192.168.105.0/24"

# NFS Storage Network (if using external storage)
NFS_VLAN_ID="106"
NFS_NETWORK="192.168.106.0/24"

# Uplink Configuration
UPLINK_INTERFACES="ether24"
TRUNK_INTERFACES="ether2,ether3,ether4,ether5,ether6,ether7,ether8"

# Bridge Configuration
BRIDGE_NAME="br-vcf"
BRIDGE_VLAN_FILTERING="yes"

# Enable DHCP for VM network (optional)
ENABLE_DHCP_VM="yes"
DHCP_POOL_START="192.168.105.100"
DHCP_POOL_END="192.168.105.200"

# DNS Configuration
DNS_SERVERS="8.8.8.8,8.8.4.4"

# SNMP Configuration (optional)
ENABLE_SNMP="no"
SNMP_COMMUNITY="public"
SNMP_LOCATION="VCF Datacenter"
EOF
    
    print_success "Sample configuration generated: $CONFIG_FILE"
    print_warning "Please edit $CONFIG_FILE before running the provisioning script"
    exit 0
}

# Function to load configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        print_warning "Run '$0 --generate-config' to create a sample configuration"
        exit 1
    fi
    
    # Source the configuration file
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    
    # Validate required variables
    local required_vars=(
        "MIKROTIK_IP"
        "MIKROTIK_USER"
        "MGMT_VLAN_ID"
        "VMOTION_VLAN_ID"
        "VSAN_VLAN_ID"
        "TEP_VLAN_ID"
        "BRIDGE_NAME"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            print_error "Required variable $var is not set in $CONFIG_FILE"
            exit 1
        fi
    done
    
    print_status "Configuration loaded from: $CONFIG_FILE"
}

# Function to execute RouterOS command
execute_ros_command() {
    local command="$1"
    local description="$2"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_status "[DRY RUN] $description"
        echo "Command: $command"
        return 0
    fi
    
    print_status "$description"
    
    if ! sshpass -p "$MIKROTIK_PASSWORD" ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 \
        "$MIKROTIK_USER@$MIKROTIK_IP" "$command"; then
        print_error "Failed to execute: $command"
        return 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if sshpass is available
    if ! command -v sshpass &> /dev/null; then
        print_error "sshpass is required but not installed"
        print_status "Install with: brew install sshpass"
        exit 1
    fi
    
    # Test SSH connection
    print_status "Testing SSH connection to MikroTik..."
    if ! sshpass -p "$MIKROTIK_PASSWORD" ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 \
        "$MIKROTIK_USER@$MIKROTIK_IP" "/system identity print" &> /dev/null; then
        print_error "Cannot connect to MikroTik at $MIKROTIK_IP"
        print_error "Please check IP address, username, and password"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to backup current configuration
backup_configuration() {
    local backup_file="mikrotik-backup-$(date +%Y%m%d-%H%M%S).backup"
    
    print_status "Creating configuration backup..."
    execute_ros_command \
        "/system backup save name=$backup_file" \
        "Creating system backup: $backup_file"
    
    print_success "Backup created: $backup_file"
}

# Function to configure basic system settings
configure_basic_system() {
    print_status "Configuring basic system settings..."
    
    # Set system identity
    execute_ros_command \
        "/system identity set name=vcf-switch-01" \
        "Setting system identity"
    
    # Configure clock and NTP
    execute_ros_command \
        "/system clock set time-zone-name=America/New_York" \
        "Setting timezone"
    
    execute_ros_command \
        "/system ntp client set enabled=yes server-dns-names=pool.ntp.org" \
        "Configuring NTP client"
    
    # Set DNS servers
    execute_ros_command \
        "/ip dns set servers=${DNS_SERVERS:-8.8.8.8,8.8.4.4}" \
        "Configuring DNS servers"
}

# Function to create bridge
create_bridge() {
    print_status "Creating bridge for VCF..."
    
    execute_ros_command \
        "/interface bridge add name=$BRIDGE_NAME vlan-filtering=${BRIDGE_VLAN_FILTERING:-yes} protocol-mode=rstp" \
        "Creating bridge: $BRIDGE_NAME"
    
    # Add interfaces to bridge
    local trunk_ports="${TRUNK_INTERFACES:-ether2,ether3,ether4,ether5,ether6,ether7,ether8}"
    IFS=',' read -ra PORTS <<< "$trunk_ports"
    
    for port in "${PORTS[@]}"; do
        execute_ros_command \
            "/interface bridge port add bridge=$BRIDGE_NAME interface=$port" \
            "Adding $port to bridge"
    done
    
    # Add uplink interfaces
    if [[ -n "${UPLINK_INTERFACES:-}" ]]; then
        IFS=',' read -ra UPLINKS <<< "$UPLINK_INTERFACES"
        for uplink in "${UPLINKS[@]}"; do
            execute_ros_command \
                "/interface bridge port add bridge=$BRIDGE_NAME interface=$uplink" \
                "Adding uplink $uplink to bridge"
        done
    fi
}

# Function to configure VLANs
configure_vlans() {
    print_status "Configuring VLANs for VCF..."
    
    # Array of VLAN configurations
    local vlans=(
        "$MGMT_VLAN_ID:Management:${MGMT_NETWORK:-}"
        "$VMOTION_VLAN_ID:vMotion:${VMOTION_NETWORK:-}"
        "$VSAN_VLAN_ID:vSAN:${VSAN_NETWORK:-}"
        "$TEP_VLAN_ID:NSX-TEP:${TEP_NETWORK:-}"
    )
    
    # Add optional VLANs if configured
    [[ -n "${EDGE_TEP_VLAN_ID:-}" ]] && vlans+=("$EDGE_TEP_VLAN_ID:NSX-Edge-TEP:${EDGE_TEP_NETWORK:-}")
    [[ -n "${VM_VLAN_ID:-}" ]] && vlans+=("$VM_VLAN_ID:VM-Network:${VM_NETWORK:-}")
    [[ -n "${NFS_VLAN_ID:-}" ]] && vlans+=("$NFS_VLAN_ID:NFS-Storage:${NFS_NETWORK:-}")
    
    for vlan_config in "${vlans[@]}"; do
        IFS=':' read -r vlan_id vlan_name vlan_network <<< "$vlan_config"
        
        # Create VLAN interface
        execute_ros_command \
            "/interface vlan add name=vlan$vlan_id vlan-id=$vlan_id interface=$BRIDGE_NAME comment=\"$vlan_name\"" \
            "Creating VLAN $vlan_id ($vlan_name)"
        
        # Configure VLAN on bridge
        execute_ros_command \
            "/interface bridge vlan add bridge=$BRIDGE_NAME vlan-ids=$vlan_id tagged=${UPLINK_INTERFACES:-ether24}" \
            "Adding VLAN $vlan_id to bridge (tagged on uplinks)"
        
        # Add IP address if network is specified
        if [[ -n "$vlan_network" ]]; then
            local vlan_ip="${vlan_network%/*}.1/${vlan_network#*/}"
            execute_ros_command \
                "/ip address add address=$vlan_ip interface=vlan$vlan_id comment=\"$vlan_name Gateway\"" \
                "Adding IP address to VLAN $vlan_id"
        fi
    done
}

# Function to configure access ports for specific VLANs
configure_access_ports() {
    print_status "Configuring access ports..."
    
    # Example: Configure specific ports as access ports for management VLAN
    # You can customize this based on your needs
    local mgmt_access_ports="${MGMT_ACCESS_PORTS:-ether9,ether10}"
    
    if [[ -n "$mgmt_access_ports" ]]; then
        IFS=',' read -ra PORTS <<< "$mgmt_access_ports"
        for port in "${PORTS[@]}"; do
            # Set port as access port for management VLAN
            execute_ros_command \
                "/interface bridge port set [find interface=$port] pvid=$MGMT_VLAN_ID" \
                "Setting $port as access port for VLAN $MGMT_VLAN_ID"
            
            # Add port to VLAN as untagged
            execute_ros_command \
                "/interface bridge vlan set [find vlan-ids=$MGMT_VLAN_ID] untagged=$port" \
                "Adding $port as untagged to VLAN $MGMT_VLAN_ID"
        done
    fi
}

# Function to configure DHCP (optional)
configure_dhcp() {
    if [[ "${ENABLE_DHCP_VM:-no}" == "yes" && -n "${VM_VLAN_ID:-}" ]]; then
        print_status "Configuring DHCP for VM network..."
        
        local pool_name="dhcp-vm-pool"
        local vm_network="${VM_NETWORK:-192.168.105.0/24}"
        local pool_start="${DHCP_POOL_START:-192.168.105.100}"
        local pool_end="${DHCP_POOL_END:-192.168.105.200}"
        local gateway="${vm_network%/*}.1"
        
        # Create DHCP pool
        execute_ros_command \
            "/ip pool add name=$pool_name ranges=$pool_start-$pool_end" \
            "Creating DHCP pool: $pool_name"
        
        # Create DHCP network
        execute_ros_command \
            "/ip dhcp-server network add address=$vm_network gateway=$gateway dns-server=${DNS_SERVERS:-8.8.8.8}" \
            "Creating DHCP network configuration"
        
        # Create DHCP server
        execute_ros_command \
            "/ip dhcp-server add name=dhcp-vm interface=vlan$VM_VLAN_ID address-pool=$pool_name disabled=no" \
            "Creating DHCP server for VM network"
        
        print_success "DHCP configured for VM network (VLAN $VM_VLAN_ID)"
    fi
}

# Function to configure security
configure_security() {
    print_status "Configuring security settings..."
    
    # Disable unnecessary services
    execute_ros_command \
        "/ip service set telnet disabled=yes" \
        "Disabling telnet service"
    
    execute_ros_command \
        "/ip service set ftp disabled=yes" \
        "Disabling FTP service"
    
    # Keep API enabled for programmatic management
    execute_ros_command \
        "/ip service set api disabled=no port=8728" \
        "Enabling API service"
    
    execute_ros_command \
        "/ip service set api-ssl disabled=no port=8729" \
        "Enabling API-SSL service"
    
    # Configure SSH service
    execute_ros_command \
        "/ip service set ssh port=22 disabled=no" \
        "Configuring SSH service"
    
    # Configure web interface
    execute_ros_command \
        "/ip service set www disabled=yes" \
        "Disabling HTTP web interface"
    
    execute_ros_command \
        "/ip service set www-ssl disabled=no port=443" \
        "Enabling HTTPS web interface"
}

# Function to configure SNMP (optional)
configure_snmp() {
    if [[ "${ENABLE_SNMP:-no}" == "yes" ]]; then
        print_status "Configuring SNMP..."
        
        execute_ros_command \
            "/snmp set enabled=yes contact=admin location=\"${SNMP_LOCATION:-Datacenter}\"" \
            "Enabling SNMP service"
        
        execute_ros_command \
            "/snmp community set [find default=yes] name=\"${SNMP_COMMUNITY:-public}\"" \
            "Setting SNMP community string"
        
        print_success "SNMP configured"
    fi
}

# Function to configure routing
configure_routing() {
    print_status "Configuring routing..."
    
    # Add default route if management gateway is configured
    if [[ -n "${MANAGEMENT_GATEWAY:-}" ]]; then
        execute_ros_command \
            "/ip route add dst-address=0.0.0.0/0 gateway=${MANAGEMENT_GATEWAY}" \
            "Adding default route via management gateway"
    fi
    
    # Enable IP forwarding
    execute_ros_command \
        "/ip settings set ip-forward=yes" \
        "Enabling IP forwarding"
}

# Function to apply final configuration
finalize_configuration() {
    print_status "Finalizing configuration..."
    
    # Set management IP if configured
    if [[ -n "${MANAGEMENT_IP:-}" && -n "${MANAGEMENT_INTERFACE:-}" ]]; then
        execute_ros_command \
            "/ip address add address=${MANAGEMENT_IP} interface=${MANAGEMENT_INTERFACE}" \
            "Setting management IP address"
    fi
    
    # Save configuration
    execute_ros_command \
        "/system backup save name=vcf-configured-$(date +%Y%m%d-%H%M%S)" \
        "Saving final configuration"
    
    print_success "Configuration finalized and saved"
}

# Function to display configuration summary
show_summary() {
    print_success "MikroTik VCF provisioning completed!"
    echo
    print_status "Configuration Summary:"
    echo "  - Bridge: $BRIDGE_NAME (VLAN filtering enabled)"
    echo "  - Management VLAN: $MGMT_VLAN_ID"
    echo "  - vMotion VLAN: $VMOTION_VLAN_ID"
    echo "  - vSAN VLAN: $VSAN_VLAN_ID"
    echo "  - NSX TEP VLAN: $TEP_VLAN_ID"
    [[ -n "${EDGE_TEP_VLAN_ID:-}" ]] && echo "  - NSX Edge TEP VLAN: $EDGE_TEP_VLAN_ID"
    [[ -n "${VM_VLAN_ID:-}" ]] && echo "  - VM Network VLAN: $VM_VLAN_ID"
    [[ -n "${NFS_VLAN_ID:-}" ]] && echo "  - NFS Storage VLAN: $NFS_VLAN_ID"
    echo
    print_status "Next steps:"
    echo "  1. Verify VLAN configuration on connected devices"
    echo "  2. Test connectivity between VCF components"
    echo "  3. Configure VMware vSphere networking to match VLANs"
    echo "  4. Validate NSX-T networking configuration"
}

# Main function
main() {
    local dry_run=false
    
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
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --generate-config)
                generate_config
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    print_status "MikroTik VCF Provisioning Script Starting..."
    
    # Load configuration if not overridden by command line
    if [[ -z "${MIKROTIK_IP:-}" ]]; then
        load_config
    fi
    
    # Set default username if not provided
    MIKROTIK_USER="${MIKROTIK_USER:-admin}"
    
    # Prompt for password if not provided
    if [[ -z "${MIKROTIK_PASSWORD:-}" ]]; then
        read -s -p "Enter MikroTik password: " MIKROTIK_PASSWORD
        echo
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Create backup
    backup_configuration
    
    # Execute configuration steps
    configure_basic_system
    create_bridge
    configure_vlans
    configure_access_ports
    configure_dhcp
    configure_security
    configure_snmp
    configure_routing
    finalize_configuration
    
    # Show summary
    show_summary
}

# Execute main function
main "$@"