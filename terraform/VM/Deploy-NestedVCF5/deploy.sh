#!/bin/bash
#
# Nested VCF 5 Quick Deployment Script
# Automates the Terraform deployment process
#

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}=========================================="
echo "Nested VCF 5 Deployment Script"
echo -e "==========================================${NC}"
echo ""

# Function to print step
print_step() {
    echo -e "${BLUE}>>> $1${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_error "terraform.tfvars not found"
    echo ""
    echo "Please create terraform.tfvars from the example:"
    echo "  cp terraform.tfvars.example terraform.tfvars"
    echo "  vim terraform.tfvars"
    echo ""
    exit 1
fi

# Run validation first
if [ -f "validate.sh" ]; then
    print_step "Running pre-deployment validation..."
    ./validate.sh
    if [ $? -ne 0 ]; then
        print_error "Validation failed. Please fix errors before deploying."
        exit 1
    fi
    echo ""
fi

# Initialize Terraform
print_step "Initializing Terraform..."
if terraform init; then
    print_success "Terraform initialized"
else
    print_error "Terraform initialization failed"
    exit 1
fi
echo ""

# Validate configuration
print_step "Validating Terraform configuration..."
if terraform validate; then
    print_success "Configuration is valid"
else
    print_error "Configuration validation failed"
    exit 1
fi
echo ""

# Format check
print_step "Checking Terraform formatting..."
terraform fmt -check || terraform fmt
echo ""

# Show plan
print_step "Generating deployment plan..."
echo ""
terraform plan -out=tfplan
echo ""

# Ask for confirmation
echo -e "${YELLOW}=========================================="
echo "Ready to deploy Nested VCF 5"
echo "==========================================${NC}"
echo ""
echo "This will deploy:"
echo "  - Resource pool for nested VCF"
echo "  - 4 (or more) nested ESXi hosts"
echo "  - Cloud Builder VM (if enabled)"
echo "  - VCF network port groups (if enabled)"
echo ""
echo "Estimated deployment time: 30-45 minutes"
echo ""

read -p "Do you want to proceed with the deployment? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Deployment cancelled."
    rm -f tfplan
    exit 0
fi

# Apply the plan
print_step "Deploying nested VCF environment..."
echo ""

if terraform apply tfplan; then
    rm -f tfplan
    echo ""
    echo -e "${GREEN}=========================================="
    echo "Deployment Complete!"
    echo "==========================================${NC}"
    echo ""
    
    # Show outputs
    print_step "Deployment Summary:"
    echo ""
    terraform output
    
    echo ""
    echo -e "${GREEN}Next Steps:${NC}"
    echo "  1. Verify ESXi hosts are accessible"
    echo "  2. Access Cloud Builder (if deployed)"
    echo "  3. Prepare VCF deployment JSON"
    echo "  4. Deploy VCF management domain"
    echo ""
    echo "See README.md for detailed post-deployment steps"
    echo ""
else
    print_error "Deployment failed"
    rm -f tfplan
    exit 1
fi
