# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

"""Agent 365 agentic on-behalf-of (OBO) token acquisition.

Mints user-delegated tokens AS a provisioned Agent 365 agent-user (which owns the
demo mailbox + has Fabric access) via a 3-leg exchange against Entra:

  1. blueprint  — client_credentials with the agent-identity blueprint client secret
                  and ``fmi_path`` = the ServiceIdentity SP.
  2. instance   — client_credentials as the ServiceIdentity SP (client assertion = leg 1).
  3. user_fic   — grant_type=user_fic, user_id = the agent-user object id -> a
                  user-delegated token for the requested resource scope.

The exchange MUST use the agent's **ServiceIdentity** SP as the instance (client_id +
fmi_path); using the AgentIdentity fails with AADSTS7002203.

``OboAgentUserCredential`` adapts this to the ``azure.core`` ``TokenCredential``
protocol so it can be handed to ``FoundryChatClient`` — Foundry then runs the model +
IQ tool loop AS the agent-user (and traces every tool natively).
"""

from __future__ import annotations

import logging
import threading
import time
from typing import Any

import httpx
from azure.core.credentials import AccessToken

logger = logging.getLogger("obo")

TOKEN_EXCHANGE_SCOPE = "api://AzureADTokenExchange/.default"
CLIENT_ASSERTION_TYPE = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"


class OboExchangeError(RuntimeError):
    """Raised when the agentic OBO exchange fails."""


class AgenticOboClient:
    """Performs the 3-leg agentic exchange for a fixed agent-user, with per-scope cache."""

    def __init__(
        self,
        tenant_id: str,
        blueprint_client_id: str,
        blueprint_secret: str,
        instance_client_id: str,
        agent_user_id: str,
    ) -> None:
        self._token_url = f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token"
        self._blueprint_id = blueprint_client_id
        self._blueprint_secret = blueprint_secret
        self._instance_id = instance_client_id
        self._agent_user_id = agent_user_id
        self._cache: dict[str, tuple[str, float]] = {}
        self._lock = threading.Lock()
        self._client = httpx.Client(timeout=30.0)

    def _post(self, stage: str, data: dict[str, str]) -> dict[str, Any]:
        resp = self._client.post(self._token_url, data=data)
        try:
            body = resp.json()
        except Exception as exc:  # noqa: BLE001
            raise OboExchangeError(f"{stage} exchange returned invalid JSON") from exc
        if resp.status_code >= 400 or not body.get("access_token"):
            raise OboExchangeError(
                f"{stage} exchange failed: {body.get('error')}: {body.get('error_description')}"
            )
        return body

    def token_for(self, scope: str) -> tuple[str, int]:
        """Return (access_token, expires_on_epoch) for ``scope`` as the agent-user."""
        with self._lock:
            cached = self._cache.get(scope)
            if cached and cached[1] > time.time() + 120:
                return cached[0], int(cached[1])

            blueprint = self._post(
                "blueprint",
                {
                    "client_id": self._blueprint_id,
                    "scope": TOKEN_EXCHANGE_SCOPE,
                    "grant_type": "client_credentials",
                    "client_secret": self._blueprint_secret,
                    "fmi_path": self._instance_id,
                },
            )["access_token"]
            instance = self._post(
                "instance",
                {
                    "client_id": self._instance_id,
                    "scope": TOKEN_EXCHANGE_SCOPE,
                    "grant_type": "client_credentials",
                    "client_assertion_type": CLIENT_ASSERTION_TYPE,
                    "client_assertion": blueprint,
                },
            )["access_token"]
            user = self._post(
                "delegated user",
                {
                    "client_id": self._instance_id,
                    "scope": scope,
                    "grant_type": "user_fic",
                    "client_assertion_type": CLIENT_ASSERTION_TYPE,
                    "client_assertion": blueprint,
                    "user_federated_identity_credential": instance,
                    "user_id": self._agent_user_id,
                },
            )
            token = user["access_token"]
            expires_on = int(time.time()) + int(user.get("expires_in", 3600))
            self._cache[scope] = (token, float(expires_on))
            return token, expires_on


class OboAgentUserCredential:
    """``azure.core`` TokenCredential that returns agent-user OBO tokens.

    Handed to ``FoundryChatClient`` so the Foundry Responses runtime runs the whole
    agent loop AS the agent-user — Fabric IQ (connection passthrough), Foundry IQ and
    Web IQ all resolve as that user, and every tool call is traced natively.
    """

    def __init__(self, obo: AgenticOboClient) -> None:
        self._obo = obo

    def get_token(self, *scopes: str, **_kwargs: Any) -> AccessToken:
        scope = scopes[0]
        token, expires_on = self._obo.token_for(scope)
        return AccessToken(token, expires_on)

    def close(self) -> None:  # parity with azure credentials
        pass
