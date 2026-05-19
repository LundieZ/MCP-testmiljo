#!/bin/bash

# Master setup script for MCP Azure project
# Runs all installation and initialization steps in sequence

set -e  # Exit on any error

SCRIPT_DIR="/home/azureuser/mcp/setup"  # Adjust if your setup scripts are in a different location

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   MCP Azure Project - Full Setup       ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print step headers
print_step() {
    echo ""
    echo -e "${YELLOW}Step $1: $2${NC}"
    echo "-------------------------------------------"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if this is a continuation after reboot
if [[ -f "/tmp/mcp_reboot_required" ]]; then
    echo "Detected previous setup was interrupted for reboot..."
    echo "Please run queue_setups.sh again after reboot to continue."
    exit 0
fi

if [[ -f "/tmp/mcp_step1_complete" ]]; then
    echo "Detected continuation after reboot..."
    rm -f "/tmp/mcp_step1_complete"
    START_STEP=2
else
    START_STEP=1
fi

# Check if scripts exist
print_step "0" "Checking setup scripts"

scripts=(
    "1_install_dependencies.sh"
    "2_setup_docker.sh"
    "3_setup_database.sh"
    "4_setup_keycloak.sh"
)

for script in "${scripts[@]}"; do
    if [[ ! -f "$SCRIPT_DIR/$script" ]]; then
        print_error "Script not found: $SCRIPT_DIR/$script"
        exit 1
    fi
done

print_success "All setup scripts found"

# Step 1: Install dependencies (only if starting from beginning)
if [[ $START_STEP -le 1 ]]; then
    print_step "1" "Installing Dependencies and Docker"
    if bash "$SCRIPT_DIR/1_install_dependencies.sh"; then
        print_success "Dependencies installation completed"
    else
        exit_code=$?
        print_error "Dependency installation failed with exit code $exit_code"
        exit 1
    fi
    
    # Check if reboot was triggered or required
    if [[ -f "/tmp/mcp_reboot_required" ]]; then
        echo ""
        echo "=========================================="
        echo "SETUP PAUSED - REBOOT REQUIRED"
        echo "=========================================="
        echo ""
        echo "A reboot is required to complete the installation."
        echo "Please reboot the system and then run queue_setups.sh again."
        echo ""
        echo "After reboot, setup will continue from step 2."
        exit 0
    fi
else
    echo "Skipping step 1 (already completed before reboot)"
fi

# Step 2: Setup Docker
print_step "2" "Setting up PostgreSQL Docker Container"
if bash "$SCRIPT_DIR/2_setup_docker.sh"; then
    print_success "Docker PostgreSQL container running"
else
    print_error "Docker setup failed"
    exit 1
fi

# Step 3: Initialize database
print_step "3" "Initializing Database Schema"
if bash "$SCRIPT_DIR/3_setup_database.sh"; then
    print_success "Database initialized"
else
    print_error "Database initialization failed"
    exit 1
fi

# Step 4: Setup keycloak
print_step "4" "Setting up Keycloak"
if bash "$SCRIPT_DIR/4_setup_keycloak.sh"; then
    print_success "Keycloak initialized"
else
    print_error "Keycloak setup failed"
    exit 1
fi

# Clean up any leftover flag files
rm -f /tmp/mcp_step1_complete /tmp/mcp_reboot_required 2>/dev/null || true

# Final summary
echo ""
echo "╔════════════════════════════════════════╗"
echo "║   Setup Complete!                      ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Summary:"
echo "  ✓ System dependencies installed"
echo "  ✓ Docker and Docker Compose installed"
echo "  ✓ Python virtual environment created"
echo "  ✓ PostgreSQL container running"
echo "  ✓ Database initialized with test data"
echo "  ✓ Keycloak initialized"
echo ""