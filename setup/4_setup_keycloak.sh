#!/bin/bash

# Setup Keycloak using docker-compose and realm export
# This script manages the Keycloak container and imports the realm configuration

set -e  # Exit on any error

echo "=========================================="
echo "Keycloak Setup"
echo "=========================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="/home/azureuser/mcp"  # Adjust if your project is in a different location
DOCKER_COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
REALM_EXPORT_FILE="$PROJECT_ROOT/realm-export.json"
KEYCLOAK_CONTAINER_NAME="keycloak"
KEYCLOAK_HOME="/opt/keycloak"

# Function to print status messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

# Check if required files exist
echo "Checking required files..."
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    print_error "docker-compose.yml not found in $PROJECT_ROOT"
    echo "Please ensure docker-compose.yml exists in the project root"
    exit 1
fi
print_success "docker-compose.yml found"

if [ ! -f "$REALM_EXPORT_FILE" ]; then
    print_error "realm-export.json not found in $PROJECT_ROOT"
    echo "Please ensure realm-export.json exists in the project root"
    exit 1
fi
print_success "realm-export.json found"

# Check if Docker is running
echo ""
echo "Checking Docker status..."
if ! docker ps &> /dev/null; then
    print_error "Docker is not running"
    echo "Please start Docker and try again"
    exit 1
fi
print_success "Docker is running"

# Stop and remove existing Keycloak container if it exists
echo ""
echo "Checking for existing Keycloak container..."
if docker ps -a --format '{{.Names}}' | grep -q "^${KEYCLOAK_CONTAINER_NAME}$"; then
    print_info "Found existing Keycloak container, stopping and removing..."
    docker-compose -f "$DOCKER_COMPOSE_FILE" down 2>/dev/null || true
    sleep 2
    print_success "Existing container removed"
fi

# Start Keycloak container
echo ""
echo "Starting Keycloak container..."
docker-compose -f "$DOCKER_COMPOSE_FILE" up -d

echo "Waiting for Keycloak to start..."
sleep 10

# Verify container is running
echo "Verifying Keycloak container status..."
if docker ps --format '{{.Names}}' | grep -q "^${KEYCLOAK_CONTAINER_NAME}$"; then
    print_success "Keycloak container is running"
    docker ps --filter "name=keycloak"
else
    print_error "Keycloak container failed to start"
    echo "Container logs:"
    docker logs "$KEYCLOAK_CONTAINER_NAME" 2>/dev/null || true
    exit 1
fi

# Wait for Keycloak to be fully ready
echo ""
echo "Waiting for Keycloak to be fully initialized..."
MAX_ATTEMPTS=120
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    # Check if container is running AND logs show it's started
    if docker ps --format '{{.Names}}' | grep -q "^${KEYCLOAK_CONTAINER_NAME}$" && \
       docker logs "$KEYCLOAK_CONTAINER_NAME" 2>/dev/null | grep -q "Keycloak.*started in"; then
        print_success "Keycloak is ready (attempt $ATTEMPT/$MAX_ATTEMPTS)"
        break
    fi
    
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        print_error "Keycloak failed to become ready after $MAX_ATTEMPTS attempts (2+ minutes)"
        echo ""
        echo "Container logs (last 50 lines):"
        docker logs "$KEYCLOAK_CONTAINER_NAME" | tail -50
        exit 1
    fi
    
    # Show progress every 10 attempts
    if [ $((ATTEMPT % 10)) -eq 0 ]; then
        echo "  Still waiting... ($ATTEMPT/$MAX_ATTEMPTS seconds)"
    fi
    sleep 1
    ATTEMPT=$((ATTEMPT + 1))
done

# Additional wait to ensure startup is complete
echo "Waiting for Keycloak to finish initialization..."
sleep 5

# Import realm configuration
echo ""
echo "=========================================="
echo "Importing Realm Configuration"
echo "=========================================="

print_info "Keycloak is now ready for realm import..."

# Method 1: Try to use Keycloak's admin CLI to import the realm
print_info "Attempting to import realm using Keycloak admin CLI..."

# Check if realm already exists
if docker exec "$KEYCLOAK_CONTAINER_NAME" bash -c "grep -r \"mcp-realm\" /opt/keycloak/data/h2/ 2>/dev/null" &>/dev/null; then
    print_success "Realm 'mcp-realm' already exists in database"
else
    # Copy the realm export file with a retry mechanism
    RETRY_COUNT=0
    MAX_RETRIES=5
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        print_info "Copying realm export file to container (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)..."
        
        if docker cp "$REALM_EXPORT_FILE" "$KEYCLOAK_CONTAINER_NAME:/opt/keycloak/data/import/realm-export.json" 2>/dev/null; then
            print_success "Realm export file copied successfully"
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                print_info "Failed to copy file, retrying in 3 seconds..."
                sleep 3
            fi
        fi
    done
    
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        print_error "Failed to copy realm export file after $MAX_RETRIES attempts"
        print_info "Trying alternative method: direct import using Keycloak CLI..."
        
        # Alternative: Use Keycloak's import command
        docker exec "$KEYCLOAK_CONTAINER_NAME" /opt/keycloak/bin/kc.sh import \
            --file /opt/keycloak/data/import/realm-export.json \
            --override false 2>/dev/null || true
    else
        # Restart Keycloak to trigger the import
        print_info "Restarting Keycloak to trigger realm import..."
        docker-compose -f "$DOCKER_COMPOSE_FILE" restart keycloak
        
        echo "Waiting for Keycloak to restart..."
        sleep 15
        
        # Verify it's running again
        WAIT_ATTEMPTS=0
        while [ $WAIT_ATTEMPTS -lt 30 ]; do
            if docker ps --format '{{.Names}}' | grep -q "^${KEYCLOAK_CONTAINER_NAME}$"; then
                if docker logs "$KEYCLOAK_CONTAINER_NAME" 2>/dev/null | grep -q "Keycloak.*started in"; then
                    print_success "Keycloak restarted successfully"
                    break
                fi
            fi
            WAIT_ATTEMPTS=$((WAIT_ATTEMPTS + 1))
            sleep 1
        done
    fi
fi

echo ""
echo "=========================================="
echo "Keycloak Setup Complete!"
echo "=========================================="
echo ""

# Extract admin credentials from docker-compose.yml
KEYCLOAK_ADMIN=$(grep -oP 'KEYCLOAK_ADMIN[=:\s]*\K[^,\n]*' "$DOCKER_COMPOSE_FILE" | head -1 | xargs)
KEYCLOAK_ADMIN_PASSWORD=$(grep -oP 'KEYCLOAK_ADMIN_PASSWORD[=:\s]*\K[^,\n]*' "$DOCKER_COMPOSE_FILE" | head -1 | xargs)

echo "Keycloak Information:"
echo "  URL: http://localhost:8080"
echo "  Admin Console: http://localhost:8080/admin"
if [ -n "$KEYCLOAK_ADMIN" ]; then
    echo "  Admin Username: $KEYCLOAK_ADMIN"
fi
if [ -n "$KEYCLOAK_ADMIN_PASSWORD" ]; then
    echo "  Admin Password: $KEYCLOAK_ADMIN_PASSWORD"
fi
echo ""
echo "Realm Import Status:"
if docker logs "$KEYCLOAK_CONTAINER_NAME" 2>/dev/null | grep -q "Import finished successfully"; then
    print_success "Realm 'mcp-realm' imported successfully!"
    echo "  • Realm: mcp-realm"
    echo "  • Users imported:"
    echo "    - admin-user (password: admin123)"
    echo "    - non-admin (password: password)"
    echo "  • Client imported:"
    echo "    - mcp-server (with secret: mcp-server-secret)"
elif docker logs "$KEYCLOAK_CONTAINER_NAME" 2>/dev/null | grep -q "Realm 'mcp-realm' already exists"; then
    print_success "Realm 'mcp-realm' is ready (already existed, not re-imported)"
else
    print_info "Checking realm status..."
    if docker logs "$KEYCLOAK_CONTAINER_NAME" 2>/dev/null | grep -q "mcp-realm"; then
        print_success "Realm 'mcp-realm' found in Keycloak"
    else
        print_info "Manually verify realm import status with: docker logs keycloak | grep -i realm"
    fi
fi
echo ""
echo "Useful Commands:"
echo "  View live logs:      docker logs -f keycloak"
echo "  View last 30 lines:  docker logs --tail 30 keycloak"
echo "  Stop Keycloak:       docker-compose -f $DOCKER_COMPOSE_FILE down"
echo "  Restart Keycloak:    docker-compose -f $DOCKER_COMPOSE_FILE restart"
echo "  Bash access:         docker exec -it keycloak bash"
echo "  Access postgres:     docker exec -it keycloak-db psql -U keycloak -d keycloak"
echo ""
echo "Next Steps:"
echo "  1. Open http://localhost:8080 in your browser"
echo "  2. Click 'Administration Console' or go to http://localhost:8080/admin"
echo "  3. Login with admin credentials:"
echo "     Username: $KEYCLOAK_ADMIN"
echo "     Password: $KEYCLOAK_ADMIN_PASSWORD"
echo "  4. Verify the 'mcp-realm' is available in the top-left realm selector"
echo "  5. Switch to 'mcp-realm' and verify:"
echo "     • Users (Manage → Users): admin-user, non-admin"
echo "     • Clients (Manage → Clients): mcp-server"
echo ""
print_success "Keycloak is running and ready!"