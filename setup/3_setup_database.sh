#!/bin/bash

# Initialize PostgreSQL database with roles, tables, and permissions
# Tests access control between app_user and mcp_admin roles

set -e  # Exit on any error

echo "=========================================="
echo "PostgreSQL Database Initialization"
echo "=========================================="

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q '^mcp-postgres$'; then
    echo "Error: mcp-postgres container is not running."
    echo "Run: bash 2_setup_docker.sh"
    exit 1
fi

echo "Initializing database schema and roles..."

# Execute SQL commands in the container
docker exec -i mcp-postgres psql -U postgres -d mcpdb << 'EOF'

-- Create application user role
CREATE ROLE app_user LOGIN PASSWORD 'app_user_pw';

-- Create admin role
CREATE ROLE mcp_admin LOGIN PASSWORD 'mcp_admin_pw';

-- Grant database connection permissions
GRANT CONNECT ON DATABASE mcpdb TO app_user;
GRANT CONNECT ON DATABASE mcpdb TO mcp_admin;

-- Create tables
CREATE TABLE IF NOT EXISTS public_data (
  id SERIAL PRIMARY KEY,
  info TEXT
);

CREATE TABLE IF NOT EXISTS admin_data (
  id SERIAL PRIMARY KEY,
  secret TEXT
);

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  amount NUMERIC(10, 2) NOT NULL,
  is_admin BOOLEAN NOT NULL DEFAULT FALSE
);

-- Insert test data
INSERT INTO public_data (info)
VALUES ('Public information - safe to expose');

INSERT INTO admin_data (secret)
VALUES ('TOP SECRET - SHOULD NEVER LEAK');

INSERT INTO users (username, amount, is_admin)
VALUES
  ('admin', 14999.00, TRUE),
  ('non-admin', 990.00, FALSE);

-- Revoke default public permissions (security)
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;

-- Grant app_user permissions (read-only on public_data and users)
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT ON public_data TO app_user;
GRANT SELECT, INSERT ON users TO app_user;

-- Grant mcp_admin permissions (full access)
GRANT USAGE ON SCHEMA public TO mcp_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO mcp_admin;

EOF

echo ""
echo "=========================================="
echo "Database Initialization Complete!"
echo "=========================================="
echo ""
echo "Roles created:"
echo "  • app_user (password: app_user_pw) - Read-only access to public_data and users"
echo "  • mcp_admin (password: mcp_admin_pw) - Full admin access"
echo ""
echo "Tables created:"
echo "  • public_data - Contains public information"
echo "  • admin_data  - Contains sensitive information"
echo "  • users       - Contains user accounts and balances"
echo ""
echo "Users inserted:"
echo "  • admin     | balance: 14999.00 | is_admin: true"
echo "  • non-admin | balance:   990.00 | is_admin: false"
echo ""
echo "Test access as app_user:"
echo "  docker exec -it mcp-postgres psql -U app_user -d mcpdb"
echo "  mcpdb=> SELECT * FROM public_data;  -- Should work"
echo "  mcpdb=> SELECT * FROM users;        -- Should work"
echo "  mcpdb=> SELECT * FROM admin_data;   -- Should fail"
echo ""
echo "Test access as mcp_admin:"
echo "  docker exec -it mcp-postgres psql -U mcp_admin -d mcpdb"
echo "  mcpdb=> SELECT * FROM admin_data;   -- Should work"
echo ""