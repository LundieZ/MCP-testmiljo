#!/bin/bash

# Install system dependencies and Python packages for MCP Azure project
# This script handles apt packages, Docker, and Python virtual environment setup

set -e  # Exit on any error

echo "=========================================="
echo "Installing Python3-pip First"
echo "=========================================="

# Update package lists first
echo "Updating system package lists..."
sudo apt update

# Install python3-pip FIRST (critical dependency)
if ! command -v pip3 &> /dev/null; then
    echo "Installing python3-pip..."
    sudo apt install -y python3-pip
else
    echo "✓ python3-pip is already installed"
fi

echo "=========================================="
echo "Installing System Dependencies"
echo "=========================================="

# Now upgrade packages
echo "Upgrading system packages..."
sudo apt upgrade -y

# Install required system packages
echo "Installing required packages..."
PACKAGES_TO_INSTALL=()

# Check each package individually
for pkg in ca-certificates curl gnupg lsb-release git jq python3 python3-venv build-essential cmake; do
    if ! dpkg -l | grep -q "^ii  $pkg"; then
        PACKAGES_TO_INSTALL+=("$pkg")
    fi
done

if [ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]; then
    echo "Installing missing packages: ${PACKAGES_TO_INSTALL[*]}"
    sudo apt install -y "${PACKAGES_TO_INSTALL[@]}"
else
    echo "✓ All required system packages are already installed"
fi

echo "=========================================="
echo "Installing Docker"
echo "=========================================="

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "Docker not found, installing..."
    curl -fsSL https://get.docker.com | sudo sh
    echo "✓ Docker installed"
else
    echo "✓ Docker is already installed"
fi

# Install Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
      -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✓ Docker Compose installed"
else
    echo "✓ Docker Compose is already installed"
fi

echo "Verifying Docker installation..."
docker --version
docker-compose --version

echo "=========================================="
echo "Setting up Python Virtual Environment"
echo "=========================================="

# Create virtual environment
if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv venv
    echo "✓ Virtual environment created"
else
    echo "✓ Virtual environment already exists"
fi

source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install Python packages
echo "Installing Python packages..."

# Install packages directly without array gymnastics
pip install \
    mcp \
    asyncpg \
    psycopg2-binary \
    httpx \
    python-jose \
    cryptography \
    pyjwt \
    pydantic \
    python-dotenv \
    openai \
    sseclient-py \
    aiohttp \
    fastmcp \
    PyPDF2

if [ $? -eq 0 ]; then
    echo "✓ All Python packages installed successfully"
else
    echo "✗ Error installing Python packages"
    exit 1
fi

echo "=========================================="
echo "Configuring Docker User Access"
echo "=========================================="

# Track if we made changes that require reboot
REBOOT_REQUIRED=false

# Check if user is in docker group
if groups azureuser | grep &>/dev/null '\bdocker\b'; then
    echo "✓ User already in docker group"
else
    echo "Adding user to docker group..."
    sudo usermod -aG docker azureuser
    echo "✓ User added to docker group"
    REBOOT_REQUIRED=true
fi

# Start and enable docker service
echo "Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Verify Docker is running
if systemctl is-active --quiet docker; then
    echo "✓ Docker service is running"
else
    echo "✗ Docker service failed to start"
    exit 1
fi

# Check if Docker commands work without sudo
if ! docker ps &> /dev/null; then
    echo ""
    echo "=========================================="
    echo "NOTE: Docker permissions not yet active"
    echo "=========================================="
    echo ""
    echo "You've been added to the docker group, but this change"
    echo "won't take effect until you start a new session."
    echo ""
    echo "For now, you'll need to use 'sudo' for docker commands"
    echo "until after reboot."
fi

# Check if reboot is needed (either from group changes or system updates)
if [ "$REBOOT_REQUIRED" = true ]; then
    echo ""
    echo "=========================================="
    echo "REBOOT REQUIRED"
    echo "=========================================="
    echo ""
    echo "System changes require a reboot:"
    echo "  • Docker group membership updated"
    echo ""
    echo "A reboot is necessary for these changes to take effect."
    echo ""
    
    # Create flag file to indicate step 1 completed
    touch /tmp/mcp_step1_complete
    touch /tmp/mcp_reboot_required
    
    while true; do
        read -p "Reboot now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Rebooting in 5 seconds..."
            echo "After reboot, run queue_setups.sh again to continue from step 2."
            sleep 5
            sudo reboot
            exit 0
        elif [[ $REPLY =~ ^[Nn]$ ]]; then
            echo ""
            echo "=========================================="
            echo "MANUAL REBOOT REQUIRED"
            echo "=========================================="
            echo ""
            echo "Please reboot manually before continuing with step 2."
            echo "Run this command when ready:"
            echo "  sudo reboot"
            echo ""
            echo "After reboot, run queue_setups.sh again."
            exit 0
        else
            echo "Please answer y or n"
        fi
    done
else
    echo ""
    echo "=========================================="
    echo "No reboot required!"
    echo "=========================================="
    echo ""
    echo "All dependencies installed successfully."
    echo "You can continue with the next setup steps."
fi

echo ""
echo "Verifying pip installations..."
pip list | grep -E "mcp|asyncpg|psycopg2|httpx|python-jose|cryptography|pyjwt|pydantic|python-dotenv|openai"

echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "To activate the virtual environment, run:"
echo "  source venv/bin/activate"
echo ""
echo "To deactivate, run:"
echo "  deactivate"
echo ""

exit 0