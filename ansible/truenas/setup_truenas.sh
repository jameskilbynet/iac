#!/bin/bash
#
# TrueNAS Setup Script
# Automates dataset and share creation using Ansible playbooks
#
# Usage:
#   ./setup_truenas.sh [nfs|smb|both]
#

set -e  # Exit on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for required environment variables
if [ -z "$TRUENAS_HOST" ]; then
    echo -e "${RED}Error: TRUENAS_HOST environment variable not set${NC}"
    echo "Example: export TRUENAS_HOST=\"192.168.1.100\""
    exit 1
fi

if [ -z "$TRUENAS_API_KEY" ]; then
    echo -e "${RED}Error: TRUENAS_API_KEY environment variable not set${NC}"
    echo "Generate an API key from TrueNAS Web UI > Account > API Keys"
    exit 1
fi

# Default to 'both' if no argument provided
SHARE_MODE=${1:-both}

# Validate share mode
if [[ ! "$SHARE_MODE" =~ ^(nfs|smb|both)$ ]]; then
    echo -e "${RED}Error: Invalid argument. Use 'nfs', 'smb', or 'both'${NC}"
    exit 1
fi

echo -e "${GREEN}=== TrueNAS Setup Script ===${NC}"
echo "Host: $TRUENAS_HOST"
echo "Pool: ${TRUENAS_POOL:-tank (default)}"
echo "Share Mode: $SHARE_MODE"
echo ""

# Step 1: Create datasets
echo -e "${YELLOW}[Step 1/2] Creating datasets...${NC}"
if ansible-playbook create_datasets.yml; then
    echo -e "${GREEN}✓ Datasets created successfully${NC}"
else
    echo -e "${RED}✗ Dataset creation failed${NC}"
    exit 1
fi
echo ""

# Step 2: Create shares
echo -e "${YELLOW}[Step 2/2] Creating shares...${NC}"

if [ "$SHARE_MODE" = "nfs" ] || [ "$SHARE_MODE" = "both" ]; then
    echo "Creating NFS shares..."
    if ansible-playbook create_shares.yml -e "share_type=nfs"; then
        echo -e "${GREEN}✓ NFS shares created successfully${NC}"
    else
        echo -e "${RED}✗ NFS share creation failed${NC}"
        exit 1
    fi
fi

if [ "$SHARE_MODE" = "smb" ] || [ "$SHARE_MODE" = "both" ]; then
    echo "Creating SMB shares..."
    if ansible-playbook create_shares.yml -e "share_type=smb"; then
        echo -e "${GREEN}✓ SMB shares created successfully${NC}"
    else
        echo -e "${RED}✗ SMB share creation failed${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo "Please verify the configuration in your TrueNAS Web UI:"
echo "  - Storage > Datasets"
echo "  - Shares > $([ "$SHARE_MODE" = "nfs" ] && echo "Unix (NFS) Shares" || [ "$SHARE_MODE" = "smb" ] && echo "Windows (SMB) Shares" || echo "Unix (NFS) Shares / Windows (SMB) Shares")"
echo ""

# Display mount examples
if [ "$SHARE_MODE" = "nfs" ] || [ "$SHARE_MODE" = "both" ]; then
    echo -e "${YELLOW}Example NFS mount command:${NC}"
    echo "  sudo mount -t nfs $TRUENAS_HOST:/mnt/${TRUENAS_POOL:-tank}/docker/appdata /mnt/docker-appdata"
    echo ""
fi

if [ "$SHARE_MODE" = "smb" ] || [ "$SHARE_MODE" = "both" ]; then
    echo -e "${YELLOW}Example SMB mount command (Linux):${NC}"
    echo "  sudo mount -t cifs //$TRUENAS_HOST/docker-appdata /mnt/docker-appdata -o username=myuser,password=mypass"
    echo ""
    echo -e "${YELLOW}Example SMB mount command (macOS):${NC}"
    echo "  mount -t smbfs //$TRUENAS_HOST/docker-appdata /Volumes/docker-appdata"
    echo ""
    echo -e "${YELLOW}Example SMB mount command (Windows):${NC}"
    echo "  net use Z: \\\\$TRUENAS_HOST\\docker-appdata"
    echo ""
fi
