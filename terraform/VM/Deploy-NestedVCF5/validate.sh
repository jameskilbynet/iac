#!/bin/bash
#
# Nested VCF 5 Deployment Validation Script
# This script validates the configuration before deployment
#

set -e

echo "=========================================="
echo "Nested VCF 5 Deployment Validation"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}✗${NC} terraform.tfvars not found"
    echo "  Please copy terraform.tfvars.example to terraform.tfvars and configure it"
    exit 1
else
    echo -e "${GREEN}✓${NC} terraform.tfvars exists"
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗${NC} Terraform is not installed"
    echo "  Please install Terraform: https://www.terraform.io/downloads"
    exit 1
else
    TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✓${NC} Terraform installed (version: $TERRAFORM_VERSION)"
fi

# Validate Terraform configuration
echo ""
echo "Validating Terraform configuration..."
if terraform validate > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Terraform configuration is valid"
else
    echo -e "${RED}✗${NC} Terraform configuration is invalid"
    terraform validate
    exit 1
fi

# Check for required variables in terraform.tfvars
echo ""
echo "Checking required variables..."

REQUIRED_VARS=(
    "vsphere_server"
    "vsphere_user"
    "vsphere_password"
    "datastore"
    "network"
    "esxi_ova_path"
    "esxi_root_password"
    "esxi_management_network"
)

MISSING_VARS=()

for VAR in "${REQUIRED_VARS[@]}"; do
    if ! grep -q "^$VAR" terraform.tfvars 2>/dev/null; then
        MISSING_VARS+=("$VAR")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠${NC} Warning: The following variables are not set in terraform.tfvars:"
    for VAR in "${MISSING_VARS[@]}"; do
        echo "  - $VAR"
    done
    echo ""
else
    echo -e "${GREEN}✓${NC} All required variables are present"
fi

# Resource requirements check
echo ""
echo "Resource Requirements:"
echo "  - Minimum 4 ESXi hosts required"
echo "  - ~32 vCPUs (8 per host × 4 hosts)"
echo "  - ~256GB RAM (64GB per host × 4 hosts)"
echo "  - ~2.1TB storage (528GB per host × 4 hosts)"
echo ""

# Network requirements
echo "Network Requirements:"
echo "  - VLANs 100-105 configured on MikroTik switches"
echo "  - Management network must be accessible"
echo "  - DNS servers must be reachable"
echo ""

# Summary
echo "=========================================="
echo -e "${GREEN}Validation Complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Review terraform.tfvars configuration"
echo "  2. Run: terraform init"
echo "  3. Run: terraform plan"
echo "  4. Run: terraform apply"
echo ""
echo "For more information, see README.md"
echo ""
