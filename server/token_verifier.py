"""Token verifier implementation with comprehensive logging."""

import logging
from typing import Any, Dict, Optional
import httpx
from urllib.parse import urlparse

logger = logging.getLogger("MCP.TokenVerifier")


class AccessToken:
    """Access token class expected by the auth middleware."""

    def __init__(self, token: str, client_id: str, scopes: list, expires_at: Optional[int] = None, resource: Optional[str] = None, claims: Optional[Dict] = None):
        self.token = token
        self.client_id = client_id
        self.scopes = scopes
        self.expires_at = expires_at
        self.resource = resource
        self.claims = claims or {}  # Store all claims here


class IntrospectionTokenVerifier:
    """Token verifier that uses OAuth 2.0 Token Introspection (RFC 7662)."""

    def __init__(
        self,
        introspection_endpoint: str,
        server_url: str,
        client_id: str,
        client_secret: str,
    ):
        self.introspection_endpoint = introspection_endpoint
        self.server_url = server_url
        self.client_id = client_id
        self.client_secret = client_secret

        parsed = urlparse(server_url)
        self.resource_server = f"{parsed.scheme}://{parsed.netloc}"

        logger.info(f" TokenVerifier initialized")
        logger.debug(f"   Introspection endpoint: {introspection_endpoint}")
        logger.debug(f"   Server URL: {server_url}")
        logger.debug(f"   Resource server: {self.resource_server}")
        logger.debug(f"   Client ID: {client_id}")

    async def verify_token(self, token: str) -> Optional[AccessToken]:
        """Verify token via introspection endpoint and return AccessToken object."""
        logger.debug(f" Verifying token: {token[:20]}...")

        if not self.introspection_endpoint.startswith(("https://", "http://")):
            logger.error(f" Invalid introspection endpoint: {self.introspection_endpoint}")
            return None

        timeout = httpx.Timeout(10.0, connect=5.0)
        limits = httpx.Limits(max_connections=10, max_keepalive_connections=5)

        async with httpx.AsyncClient(
            timeout=timeout,
            limits=limits,
            verify=True,
        ) as client:
            try:
                form_data = {
                    "token": token,
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                }
                headers = {"Content-Type": "application/x-www-form-urlencoded"}

                logger.debug(f" Calling introspection endpoint: {self.introspection_endpoint}")

                response = await client.post(
                    self.introspection_endpoint,
                    data=form_data,
                    headers=headers,
                )

                logger.debug(f" Introspection response status: {response.status_code}")

                if response.status_code != 200:
                    logger.error(f" Introspection failed with status {response.status_code}")
                    logger.debug(f"Response: {response.text}")
                    return None

                data = response.json()
                logger.debug(f"[CLAIMS DEBUG] Full introspection response: {data}")
                logger.debug(f"Introspection result: active={data.get('active')}")

                if not data.get("active", False):
                    logger.warning(" Token is not active")
                    return None

                # Validate scope
                if not self._validate_scope(data):
                    logger.warning(" Token scope validation failed")
                    return None

                # Log successful verification with user info
                username = data.get('username', data.get('preferred_username', 'unknown'))
                roles = data.get('realm_access', {}).get('roles', []) if data.get('realm_access') else []
                scope = data.get('scope', '')
                scopes_list = scope.split() if scope else []

                logger.info(f" Token verified for user: {username}")
                logger.debug(f"   User roles: {roles}")
                logger.debug(f"   Scope: {scope}")
                logger.debug(f"   Token expires: {data.get('exp')}")

                # Return AccessToken object with all claims
                return AccessToken(
                    token=token,
                    client_id=data.get('client_id', 'unknown'),
                    scopes=scopes_list,
                    expires_at=data.get('exp'),
                    resource=data.get('aud'),
                    claims=data  # Store full introspection data
                )

            except httpx.ConnectError as e:
                logger.error(f" Connection error to introspection endpoint: {e}")
                logger.error(f"   Endpoint: {self.introspection_endpoint}")
                return None
            except Exception as e:
                logger.error(f" Error verifying token: {e}", exc_info=True)
                return None

    def _validate_scope(self, token_data: Dict[str, Any]) -> bool:
        """Validate token has required scopes."""
        scope = token_data.get('scope', '')
        scopes = scope.split() if scope else []

        logger.debug(f"Token scopes: {scopes}")

        if 'mcp:tools' not in scopes:
            logger.warning(f" Token missing mcp:tools scope. Has: {scopes}")
            return False

        logger.debug(f" Scope validation passed")
        return True