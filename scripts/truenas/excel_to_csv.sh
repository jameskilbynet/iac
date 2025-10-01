#!/bin/bash
#
# Excel to CSV Converter
#
# This script converts Excel files (.xlsx, .xls) to CSV format
# for use with the TrueNAS dataset creator script.
#
# Usage: ./excel_to_csv.sh <excel_file> [output_file]
#
# Requires: python3 with pandas and openpyxl packages
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
Usage: $0 <excel_file> [output_file]

Convert Excel files to CSV format for TrueNAS dataset creation

ARGUMENTS:
    excel_file      Path to Excel file (.xlsx or .xls)
    output_file     Output CSV file path (optional, defaults to excel_file.csv)

EXAMPLES:
    $0 datasets.xlsx
    $0 datasets.xlsx my_datasets.csv

REQUIREMENTS:
    - python3
    - pandas package (pip install pandas)
    - openpyxl package (pip install openpyxl)

EOF
}

check_requirements() {
    # Check if python3 is available
    if ! command -v python3 &> /dev/null; then
        log_error "python3 is required but not installed"
        return 1
    fi

    # Check if required Python packages are available
    if ! python3 -c "import pandas, openpyxl" 2>/dev/null; then
        log_error "Required Python packages not found"
        log_info "Please install them with: pip install pandas openpyxl"
        return 1
    fi

    return 0
}

convert_excel_to_csv() {
    local excel_file="$1"
    local csv_file="$2"
    
    log_info "Converting $excel_file to $csv_file..."
    
    # Python script to convert Excel to CSV
    python3 << EOF
import pandas as pd
import sys

try:
    # Read Excel file
    df = pd.read_excel('$excel_file')
    
    # Convert to CSV
    df.to_csv('$csv_file', index=False)
    
    print(f"Successfully converted {len(df)} rows to CSV")
    
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
EOF

    if [ $? -eq 0 ]; then
        log_success "Conversion completed: $csv_file"
        log_info "File contains $(wc -l < "$csv_file") lines (including header)"
    else
        log_error "Conversion failed"
        return 1
    fi
}

main() {
    if [ $# -lt 1 ] || [ $# -gt 2 ]; then
        show_usage
        exit 1
    fi
    
    local excel_file="$1"
    local csv_file="${2:-${excel_file%.*}.csv}"
    
    # Validate input file exists
    if [ ! -f "$excel_file" ]; then
        log_error "Excel file not found: $excel_file"
        exit 1
    fi
    
    # Check file extension
    case "${excel_file,,}" in
        *.xlsx|*.xls)
            ;;
        *)
            log_error "File must have .xlsx or .xls extension"
            exit 1
            ;;
    esac
    
    # Check requirements
    if ! check_requirements; then
        exit 1
    fi
    
    # Perform conversion
    convert_excel_to_csv "$excel_file" "$csv_file"
    
    log_info "You can now use the CSV file with:"
    log_info "./truenas_dataset_creator.sh $csv_file"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi