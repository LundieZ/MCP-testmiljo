# Bachelor - README

A bachelor theses about Model Context Protocol (MCP).

## Overview

This readme contains a step by step guide on how to set up the test enviroment we used in our thesis.
## Prerequisites

Before cloning this repository, ensure you have the following installed:

- **Git** (v2.0 or higher)
- **[Language/Runtime]** (Python 3.8+)

## Clone the Repository

```bash
git clone https://github.com/LundieZ/mcp.git
cd mcp
```

note: You will be asked for credentials when cloning the repository. A git token may be required to do so.
git -> settings -> developer settings -> personal access tokens -> generate new token (select scopes). Check the "repo" scope.

```

## Installation

### Step 1: Give Execute Permissions

```bash
chmod -R +x ~/mcp/setup
```

### Step 2: Run setup and reboot
```bash
~/mcp/setup/queue_setups.sh
```

```
When prompted to restart, click "y" to reboot the system after you have installed the dependencies.
When the system has restarted, run the setup script again to continue with the remaining setup steps.
On the next run, when prompted to reboot, type "n".
When prompted if you have restarted, click "y" to continue with the setup.
```


### Step 3: Configure Environment Variables

Copy the example environment file and update with your settings:

```bash
touch .env
```

Edit `.env` with your configuration:
```
# Keycloak Configuration
KEYCLOAK_URL=http://localhost:8080
KEYCLOAK_REALM=mcp-realm
MCP_SERVER_CLIENT_ID=mcp-server
MCP_SERVER_CLIENT_SECRET=mcp-server-secret
MCP_SCOPE=mcp:tools

# Database Configuration
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=mcpdb
APP_DB_USER=app_user
APP_DB_PASSWORD=app_user_pw
ADMIN_DB_USER=mcp_admin
ADMIN_DB_PASSWORD=mcp_admin_pw

# Server Configuration
HOST=localhost
PORT=3000
TRANSPORT=streamable-http
```

# ====== Configuration ======
MCP_SERVER_URL = http://localhost:3000/mcp
KEYCLOAK_URL = http://localhost:8080
KEYCLOAK_REALM = mcp-realm

# Azure OpenAI configuration
AZURE_ENDPOINT = <your-azure-endpoint>
AZURE_API_KEY = <your-azure-api-key>
AZURE_API_VERSION = 2024-02-15-preview
AZURE_DEPLOYMENT = gpt-4o


## Project Structure

```
project-name/
├── mcp/                  # Source code
├── Client/               # Client folder
    └── mcp_client.py     # Client implementation  
├── Server/               # Server folder
    ├── config.py         # Configuration settings
    ├── token_verifier.py # Token verification logic
    ├── mcp_server.py     # Main server file
    └── mcp_server.py     # Server implementation
├── .env                  # Environment variables
├── docker-compose.yml    # Docker configuration
├── requirements.txt      # Python dependencies
├── realm-export.json     # Keycloak realm export
└── README.md             # This file
```

```
To start the server and client, run the following commands in two separate terminal windows:
# Terminal 1: SSH into the server with port 3000:
ssh -i <path-to-private-key> -L 3000:localhost:3000 azureuser@<server-ip>

source ~/mcp/venv/bin/activate
python3 mcp/server/mcp_server.py


# Terminal 2: SSH into the server with port 8080:
ssh -i <path-to-private-key> -L 8080:localhost:8080 azureuser@<server-ip>

#run the client script:
source ~/mcp/venv/bin/activate
python3 mcp/client/mcp_client.py
```

When you run the client script, you will see a link. Open it in a browser to authenticate with Keycloak. The credentials for the non admin user are: non-admin / password, and for the admin it is: admin / admin. 

You are now ready to test the Model Context Protocol (MCP) implementation.

---

**Last Updated:** [03.03.2026]  
**Version:** 1.0.0
