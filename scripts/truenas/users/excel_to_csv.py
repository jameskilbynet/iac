#!/usr/bin/env python3
"""
Excel to CSV Converter for TrueNAS User Management

This script converts Excel spreadsheets (.xlsx, .xls) to CSV format
for use with TrueNAS user creation scripts. It handles multiple sheets,
validates column names, and provides options for output customization.

Usage: python3 excel_to_csv.py [OPTIONS] <input_file>

Requirements:
    pip install pandas openpyxl

Author: Generated for TrueNAS automation
"""

import argparse
import sys
import os
import pandas as pd
from pathlib import Path
import logging

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

# Valid column names for user CSV
VALID_USER_COLUMNS = {
    'username', 'full_name', 'password', 'email', 'uid', 'primary_group',
    'secondary_groups', 'home_directory', 'shell', 'locked', 'password_disabled',
    'sudo_enabled', 'ssh_public_key', 'quota', 'comments'
}

# Required columns
REQUIRED_COLUMNS = {'username', 'full_name'}

# Column aliases (alternative names that will be mapped to standard names)
COLUMN_ALIASES = {
    'user': 'username',
    'name': 'full_name',
    'display_name': 'full_name',
    'fullname': 'full_name',
    'user_name': 'username',
    'login': 'username',
    'mail': 'email',
    'email_address': 'email',
    'user_id': 'uid',
    'userid': 'uid',
    'group': 'primary_group',
    'main_group': 'primary_group',
    'groups': 'secondary_groups',
    'additional_groups': 'secondary_groups',
    'home': 'home_directory',
    'home_dir': 'home_directory',
    'login_shell': 'shell',
    'disabled': 'locked',
    'account_locked': 'locked',
    'no_password': 'password_disabled',
    'admin': 'sudo_enabled',
    'sudo': 'sudo_enabled',
    'superuser': 'sudo_enabled',
    'ssh_key': 'ssh_public_key',
    'public_key': 'ssh_public_key',
    'disk_quota': 'quota',
    'note': 'comments',
    'description': 'comments',
    'notes': 'comments'
}

def parse_arguments():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description='Convert Excel files to CSV format for TrueNAS user management',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python3 excel_to_csv.py users.xlsx
    python3 excel_to_csv.py users.xlsx --output converted_users.csv
    python3 excel_to_csv.py users.xlsx --sheet "Employee List"
    python3 excel_to_csv.py users.xlsx --dry-run
    
Column Mapping:
    The script automatically maps common column names to standard format:
    - 'name', 'display_name' → 'full_name'
    - 'user', 'login' → 'username'
    - 'mail', 'email_address' → 'email'
    - 'group', 'main_group' → 'primary_group'
    - And many more...

Required Columns:
    - username (or alias like 'user', 'login')
    - full_name (or alias like 'name', 'display_name')
        """)
    
    parser.add_argument('input_file', 
                       help='Path to Excel file (.xlsx or .xls)')
    
    parser.add_argument('-o', '--output', 
                       help='Output CSV file path (default: input_file.csv)')
    
    parser.add_argument('-s', '--sheet', 
                       help='Specific sheet name to convert (default: first sheet)')
    
    parser.add_argument('-l', '--list-sheets', 
                       action='store_true',
                       help='List all sheet names in the Excel file and exit')
    
    parser.add_argument('--dry-run', 
                       action='store_true',
                       help='Preview the conversion without saving CSV file')
    
    parser.add_argument('--validate-only', 
                       action='store_true',
                       help='Only validate the Excel file structure, do not convert')
    
    parser.add_argument('--skip-empty-rows', 
                       action='store_true', 
                       default=True,
                       help='Skip empty rows (default: True)')
    
    parser.add_argument('--encoding', 
                       default='utf-8',
                       help='Output CSV encoding (default: utf-8)')
    
    parser.add_argument('-v', '--verbose', 
                       action='store_true',
                       help='Enable verbose logging')
    
    return parser.parse_args()

def setup_logging(verbose):
    """Setup logging based on verbosity level."""
    if verbose:
        logger.setLevel(logging.DEBUG)
        handler = logging.StreamHandler()
        handler.setLevel(logging.DEBUG)
        formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)
        logger.handlers = [handler]

def validate_input_file(file_path):
    """Validate that the input file exists and is a valid Excel file."""
    if not os.path.exists(file_path):
        logger.error(f"File not found: {file_path}")
        return False
    
    if not os.path.isfile(file_path):
        logger.error(f"Path is not a file: {file_path}")
        return False
    
    # Check file extension
    valid_extensions = ['.xlsx', '.xls']
    file_ext = Path(file_path).suffix.lower()
    
    if file_ext not in valid_extensions:
        logger.error(f"Invalid file type: {file_ext}. Supported types: {', '.join(valid_extensions)}")
        return False
    
    # Try to read the file to check if it's valid
    try:
        pd.ExcelFile(file_path)
        return True
    except Exception as e:
        logger.error(f"Cannot read Excel file: {e}")
        return False

def list_sheets(file_path):
    """List all sheet names in the Excel file."""
    try:
        excel_file = pd.ExcelFile(file_path)
        logger.info(f"Sheets in {file_path}:")
        for i, sheet in enumerate(excel_file.sheet_names, 1):
            logger.info(f"  {i}. {sheet}")
        return excel_file.sheet_names
    except Exception as e:
        logger.error(f"Error reading Excel file: {e}")
        return None

def normalize_column_names(columns):
    """Normalize column names using aliases and convert to lowercase."""
    normalized = []
    original_mapping = {}
    
    for col in columns:
        if pd.isna(col) or str(col).strip() == '':
            continue
            
        # Convert to lowercase and strip whitespace
        col_clean = str(col).lower().strip()
        
        # Replace spaces and special characters with underscores
        col_clean = col_clean.replace(' ', '_').replace('-', '_').replace('.', '_')
        
        # Check for direct match in valid columns
        if col_clean in VALID_USER_COLUMNS:
            normalized.append(col_clean)
            original_mapping[col_clean] = str(col)
        # Check for alias match
        elif col_clean in COLUMN_ALIASES:
            normalized_name = COLUMN_ALIASES[col_clean]
            normalized.append(normalized_name)
            original_mapping[normalized_name] = str(col)
        else:
            # Keep unknown columns as-is but warn
            normalized.append(col_clean)
            original_mapping[col_clean] = str(col)
            logger.warning(f"Unknown column '{col}' will be kept as '{col_clean}'")
    
    return normalized, original_mapping

def validate_dataframe(df, original_mapping):
    """Validate the dataframe has required columns and data."""
    columns = set(df.columns)
    
    # Check for required columns
    missing_required = REQUIRED_COLUMNS - columns
    if missing_required:
        logger.error(f"Missing required columns: {', '.join(missing_required)}")
        logger.info("Available columns:")
        for col in df.columns:
            original_name = original_mapping.get(col, col)
            logger.info(f"  - {col} (original: '{original_name}')")
        return False
    
    # Check for data
    if df.empty:
        logger.error("Excel sheet contains no data rows")
        return False
    
    # Validate username column has no empty values
    if df['username'].isna().any() or (df['username'] == '').any():
        empty_count = df['username'].isna().sum() + (df['username'] == '').sum()
        logger.error(f"Username column contains {empty_count} empty values")
        return False
    
    # Validate full_name column has no empty values
    if df['full_name'].isna().any() or (df['full_name'] == '').any():
        empty_count = df['full_name'].isna().sum() + (df['full_name'] == '').sum()
        logger.error(f"Full name column contains {empty_count} empty values")
        return False
    
    logger.info(f"Validation successful: {len(df)} users found")
    return True

def clean_dataframe(df):
    """Clean the dataframe data."""
    # Remove rows where both username and full_name are empty
    df = df.dropna(subset=['username', 'full_name'], how='all')
    
    # Convert boolean columns
    boolean_columns = ['locked', 'password_disabled', 'sudo_enabled']
    for col in boolean_columns:
        if col in df.columns:
            # Convert various representations to boolean
            df[col] = df[col].astype(str).str.lower().map({
                'true': 'true', '1': 'true', 'yes': 'true', 'y': 'true',
                'false': 'false', '0': 'false', 'no': 'false', 'n': 'false',
                'nan': 'false', '': 'false'
            }).fillna('false')
    
    # Clean up string columns
    string_columns = ['username', 'full_name', 'email', 'primary_group', 'shell', 'comments']
    for col in string_columns:
        if col in df.columns:
            df[col] = df[col].astype(str).str.strip()
            # Replace 'nan' with empty string
            df[col] = df[col].replace('nan', '')
    
    # Clean secondary_groups - ensure proper comma separation
    if 'secondary_groups' in df.columns:
        def clean_groups(groups_str):
            if pd.isna(groups_str) or str(groups_str).lower() == 'nan' or groups_str == '':
                return ''
            # Split by various delimiters and rejoin with commas
            groups = str(groups_str).replace(';', ',').replace('|', ',')
            groups_list = [g.strip() for g in groups.split(',') if g.strip()]
            return ','.join(groups_list)
        
        df['secondary_groups'] = df['secondary_groups'].apply(clean_groups)
    
    return df

def read_excel_sheet(file_path, sheet_name=None):
    """Read Excel sheet and return normalized dataframe."""
    try:
        # Read the Excel file
        if sheet_name:
            df = pd.read_excel(file_path, sheet_name=sheet_name)
            logger.info(f"Reading sheet '{sheet_name}' from {file_path}")
        else:
            df = pd.read_excel(file_path)
            logger.info(f"Reading first sheet from {file_path}")
        
        if df.empty:
            logger.error("Excel sheet is empty")
            return None, None
        
        logger.debug(f"Original shape: {df.shape}")
        logger.debug(f"Original columns: {list(df.columns)}")
        
        # Normalize column names
        normalized_columns, original_mapping = normalize_column_names(df.columns)
        df.columns = normalized_columns
        
        logger.info(f"Column mapping:")
        for new_col, orig_col in original_mapping.items():
            if new_col != orig_col.lower().replace(' ', '_'):
                logger.info(f"  '{orig_col}' → '{new_col}'")
        
        # Clean the dataframe
        df = clean_dataframe(df)
        
        logger.debug(f"Cleaned shape: {df.shape}")
        logger.info(f"Found {len(df)} data rows")
        
        return df, original_mapping
        
    except Exception as e:
        logger.error(f"Error reading Excel sheet: {e}")
        return None, None

def preview_conversion(df, max_rows=10):
    """Preview the conversion results."""
    logger.info("Conversion Preview:")
    logger.info("=" * 50)
    
    # Show column information
    logger.info(f"Columns ({len(df.columns)}):")
    for col in df.columns:
        non_empty = df[col].notna().sum()
        logger.info(f"  - {col}: {non_empty} non-empty values")
    
    logger.info(f"\nFirst {min(max_rows, len(df))} rows:")
    logger.info("-" * 50)
    
    # Display sample data
    for idx, row in df.head(max_rows).iterrows():
        logger.info(f"Row {idx + 1}:")
        for col in ['username', 'full_name', 'email', 'primary_group']:
            if col in df.columns:
                value = row[col] if pd.notna(row[col]) and row[col] != '' else '<empty>'
                logger.info(f"  {col}: {value}")
        logger.info("")

def write_csv(df, output_path, encoding='utf-8'):
    """Write dataframe to CSV file."""
    try:
        # Ensure output directory exists
        output_dir = os.path.dirname(output_path)
        if output_dir and not os.path.exists(output_dir):
            os.makedirs(output_dir)
        
        # Write CSV
        df.to_csv(output_path, index=False, encoding=encoding)
        logger.info(f"CSV file created: {output_path}")
        
        # Show file info
        file_size = os.path.getsize(output_path)
        logger.info(f"File size: {file_size} bytes")
        logger.info(f"Rows: {len(df)}, Columns: {len(df.columns)}")
        
        return True
        
    except Exception as e:
        logger.error(f"Error writing CSV file: {e}")
        return False

def main():
    """Main function."""
    args = parse_arguments()
    
    # Setup logging
    setup_logging(args.verbose)
    
    logger.info("Excel to CSV Converter for TrueNAS User Management")
    logger.info("=" * 55)
    
    # Validate input file
    if not validate_input_file(args.input_file):
        sys.exit(1)
    
    # List sheets if requested
    if args.list_sheets:
        sheets = list_sheets(args.input_file)
        if sheets is None:
            sys.exit(1)
        sys.exit(0)
    
    # Read Excel file
    df, original_mapping = read_excel_sheet(args.input_file, args.sheet)
    if df is None:
        sys.exit(1)
    
    # Validate data
    if not validate_dataframe(df, original_mapping):
        sys.exit(1)
    
    # Validation-only mode
    if args.validate_only:
        logger.info("✓ Excel file validation completed successfully")
        sys.exit(0)
    
    # Preview mode
    if args.dry_run:
        preview_conversion(df)
        logger.info("✓ Dry run completed - no files were created")
        sys.exit(0)
    
    # Determine output path
    if args.output:
        output_path = args.output
    else:
        input_path = Path(args.input_file)
        output_path = input_path.with_suffix('.csv')
    
    # Preview before writing
    logger.info(f"Converting to: {output_path}")
    preview_conversion(df, max_rows=3)
    
    # Write CSV file
    if write_csv(df, output_path, args.encoding):
        logger.info("✓ Conversion completed successfully")
        logger.info(f"Next steps:")
        logger.info(f"  1. Review the CSV file: {output_path}")
        logger.info(f"  2. Test with dry-run: ./truenas_user_creator.sh --dry-run {output_path}")
        logger.info(f"  3. Create users: ./truenas_user_creator.sh {output_path}")
    else:
        logger.error("✗ Conversion failed")
        sys.exit(1)

if __name__ == "__main__":
    main()