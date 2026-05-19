"""Configuration settings for the MCP database server."""

import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

from typing import Optional

class Config:
    """Configuration class that loads from environment variables."""

    # Server settings
    HOST: str = os.getenv("HOST", "localhost")
    PORT: int = int(os.getenv("PORT", "3000"))

    # Auth server settings (Keycloak)
    KEYCLOAK_URL: str = os.getenv("KEYCLOAK_URL", "http://localhost:8080")
    KEYCLOAK_REALM: str = os.getenv("KEYCLOAK_REALM", "master")

    # OAuth client settings (for token introspection)
    MCP_SERVER_CLIENT_ID: str = os.getenv("MCP_SERVER_CLIENT_ID", "mcp-server")
    MCP_SERVER_CLIENT_SECRET: str = os.getenv("MCP_SERVER_CLIENT_SECRET", "")

    # Database settings - Updated to match your docker container
    DB_HOST: str = os.getenv("DB_HOST", "127.0.0.1")  # Using 127.0.0.1 as per your docker run
    DB_PORT: int = int(os.getenv("DB_PORT", "5432"))  # Added DB_PORT
    DB_NAME: str = os.getenv("DB_NAME", "mcpdb")
    APP_DB_USER: str = os.getenv("APP_DB_USER", "app_user")
    APP_DB_PASSWORD: str = os.getenv("APP_DB_PASSWORD", "app_user_pw")
    ADMIN_DB_USER: str = os.getenv("ADMIN_DB_USER", "mcp_admin")
    ADMIN_DB_PASSWORD: str = os.getenv("ADMIN_DB_PASSWORD", "mcp_admin_pw")

    # MCP settings
    MCP_SCOPE: str = os.getenv("MCP_SCOPE", "mcp:tools")
    TRANSPORT: str = os.getenv("TRANSPORT", "streamable-http")

    @property
    def server_url(self) -> str:
        """Build the server URL."""
        return f"http://{self.HOST}:{self.PORT}"

    @property
    def auth_base_url(self) -> str:
        """Build the auth server base URL."""
        return f"{self.KEYCLOAK_URL}/realms/{self.KEYCLOAK_REALM}/"

    @property
    def introspection_endpoint(self) -> str:
        """Get the token introspection endpoint."""
        return f"{self.auth_base_url}protocol/openid-connect/token/introspect"

    @property
    def authorization_endpoint(self) -> str:
        """Get the authorization endpoint."""
        return f"{self.auth_base_url}protocol/openid-connect/auth"

    @property
    def token_endpoint(self) -> str:
        """Get the token endpoint."""
        return f"{self.auth_base_url}protocol/openid-connect/token"

    @property
    def device_endpoint(self) -> str:
        """Get the device authorization endpoint."""
        return f"{self.auth_base_url}protocol/openid-connect/auth/device"

    @property
    def database_url(self) -> str:
        """Get database URL for connection."""
        return f"postgresql://{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"

    def validate(self) -> None:
        """Validate configuration."""
        if not self.MCP_SERVER_CLIENT_SECRET:
            raise ValueError("MCP_SERVER_CLIENT_SECRET must be set")
        if self.TRANSPORT not in ["sse", "streamable-http"]:
            raise ValueError(f"Invalid transport: {self.TRANSPORT}")


# Global configuration instance
config = Config()