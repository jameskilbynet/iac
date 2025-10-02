#!/bin/bash

#################################################################
# MikroTik Configuration Extractor Wrapper Script
# 
# This script provides a convenient wrapper around the Python
# config extraction tool with dependency checking
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

# Function to check dependencies
check_dependencies() {
    print_status "Checking dependencies..."
    
    # Check if virtual environment exists
    if [[ ! -f "$SCRIPT_DIR/venv/bin/python3" ]]; then
        print_error "Virtual environment not found at $SCRIPT_DIR/venv"
        print_status "Create virtual environment: python3 -m venv venv"
        print_status "Install dependencies: source venv/bin/activate && pip install routeros-api"
        exit 1
    fi
    
    # Check if routeros-api is installed in virtual environment
    if ! "$SCRIPT_DIR/venv/bin/python3" -c "import routeros_api" &> /dev/null; then
        print_warning "routeros-api package not found in virtual environment"
        print_status "Installing Python dependencies..."
        
        if [[ -f "$SCRIPT_DIR/requirements.txt" ]]; then
            "$SCRIPT_DIR/venv/bin/pip" install -r "$SCRIPT_DIR/requirements.txt"
        else
            "$SCRIPT_DIR/venv/bin/pip" install routeros-api
        fi
        
        print_success "Dependencies installed"
    else
        print_success "Dependencies satisfied"
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

This script extracts configuration from a MikroTik router via API and generates
reusable configuration files.

OPTIONS:
    -h, --help              Show this help message
    -H, --host ADDRESS      MikroTik IP address (default: 192.168.3.1)
    -P, --port PORT         API port (default: 8728)
    -u, --username USER     Username (default: admin)
    -p, --password PASS     Password (will prompt if not provided)
    -o, --output-dir DIR    Output directory (default: current directory)
    --ssl                   Use SSL connection (port 8729)
    --json                  Also generate JSON output
    --prefix PREFIX         Output file prefix (default: extracted)

EXAMPLES:
    $0                                          # Extract from 192.168.3.1
    $0 -H 192.168.1.1 -u admin                # Different host
    $0 --ssl --json                           # SSL connection with JSON
    $0 -o ./configs --prefix mikrotik01       # Custom output location

OUTPUT FILES:
    • {prefix}_{host}_{timestamp}.rsc         - RouterOS import script
    • {prefix}_{host}_{timestamp}.env         - Environment file for provisioning
    • {prefix}_{host}_{timestamp}.json        - Raw JSON data (if --json used)

EOF
}

# Main function
main() {
    # Parse basic help option
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    print_status "MikroTik Configuration Extractor"
    
    # Check dependencies
    check_dependencies
    
    # Execute Python script with all arguments
    "$SCRIPT_DIR/venv/bin/python3" "$SCRIPT_DIR/extract-mikrotik-config.py" "$@"
}

# Execute main function
main "$@"