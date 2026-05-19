#!/bin/bash

# Setup and start Docker PostgreSQL container for MCP project

set -e  # Exit on any error

echo "=========================================="
echo "Docker PostgreSQL Setup"
echo "=========================================="

# Check if Docker is running
echo "Checking Docker status..."
if ! docker ps &> /dev/null; then
    echo "Error: Docker is not running or you don't have permissions."
    echo "Try adding your user to docker group: sudo usermod -aG docker $USER"
    exit 1
fi

# Stop and remove existing container if it exists
if docker ps -a --format '{{.Names}}' | grep -q '^mcp-postgres$'; then
    echo "Stopping existing mcp-postgres container..."
    docker stop mcp-postgres 2>/dev/null || true
    echo "Removing existing mcp-postgres container..."
    docker rm mcp-postgres 2>/dev/null || true
fi

# Create and start PostgreSQL container
echo "Starting PostgreSQL container..."
docker run -d \
  --name mcp-postgres \
  --restart unless-stopped \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=mcpdb \
  -p 127.0.0.1:5432:5432 \
  postgres:16

echo "Waiting for PostgreSQL to be ready..."
# Wait longer and check if PostgreSQL is actually accepting connections
for i in {1..30}; do
    if docker exec mcp-postgres pg_isready -U postgres &> /dev/null; then
        echo "✓ PostgreSQL is ready (attempt $i/30)"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "✗ PostgreSQL failed to become ready after 30 attempts"
        docker logs mcp-postgres
        exit 1
    fi
    sleep 1
done

# Verify container is running
if docker ps --format '{{.Names}}' | grep -q '^mcp-postgres$'; then
    echo "✓ PostgreSQL container is running"
    docker ps --filter "name=mcp-postgres"
else
    echo "✗ Error: PostgreSQL container failed to start"
    docker logs mcp-postgres
    exit 1
fi

echo ""
echo "=========================================="
echo "PostgreSQL Setup Complete!"
echo "=========================================="
echo ""
echo "Connection details:"
echo "  Host: 127.0.0.1"
echo "  Port: 5432"
echo "  Username: postgres"
echo "  Password: postgres"
echo "  Database: mcpdb"
echo ""
echo "To access the database:"
echo "  docker exec -it mcp-postgres psql -U postgres -d mcpdb"
echo ""