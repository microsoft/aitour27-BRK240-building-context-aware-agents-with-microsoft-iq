# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

"""Caldova Supply — classic Foundry hosted agent (agent-framework).

This is the **Foundry-native** build: Foundry runs the model + tool loop (via
``FoundryChatClient`` + ``ResponsesHostServer``), so the Foundry portal Playground
chats with it AND the **Traces tab shows each IQ tool call by name** — no hand-rolled
Responses loop.

The four Caldova IQs are attached as Foundry **hosted tools** (resolved server-side
from the project connections). The client authenticates as a provisioned Agent 365
agent-user via agentic **OBO** (see ``obo.py``), so Fabric IQ (connection passthrough),
Foundry IQ and Web IQ resolve as that user with real data, and Work IQ reads the
agent-user's mailbox.

Story: **hosted agent + 4 IQs in Foundry** — independent of the Teams autopilot.
"""

from __future__ import annotations

import logging
import os

from agent_framework import Agent
from agent_framework.foundry import FoundryChatClient
from agent_framework_foundry_hosting import ResponsesHostServer

from obo import AgenticOboClient, OboAgentUserCredential

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("main")

WORK_IQ_SCOPE = "api://workiq.svc.cloud.microsoft/WorkIQAgent.Ask"


def _require(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Required environment variable is not set: {name}")
    return value


def _load_instructions() -> str:
    path = os.path.join(os.path.dirname(__file__), "instructions.md")
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except OSError:
        return "You are the Caldova Supply analyst. Route each question to the right IQ."


def build_agent() -> Agent:
    project_endpoint = os.getenv("IQ_PROJECT_ENDPOINT") or _require("AZURE_AI_PROJECT_ENDPOINT")
    model = os.getenv("ModelDeployment") or os.getenv("FOUNDRY_MODEL_NAME") or "gpt-5.4-mini"

    # --- Agentic OBO: run the whole loop AS the provisioned agent-user ---------------
    obo = AgenticOboClient(
        tenant_id=_require("TENANT_ID"),
        blueprint_client_id=_require("OBO_BLUEPRINT_CLIENT_ID"),
        blueprint_secret=_require("OBO_BLUEPRINT_SECRET"),
        instance_client_id=_require("OBO_INSTANCE_CLIENT_ID"),
        agent_user_id=_require("OBO_AGENT_USER_ID"),
    )
    credential = OboAgentUserCredential(obo)

    client = FoundryChatClient(
        project_endpoint=project_endpoint,
        model=model,
        credential=credential,
        allow_preview=True,
    )

    tools: list = []

    # 1) Web IQ — real-time web search MCP
    web_conn = os.getenv("WEB_IQ_CONNECTION_ID", "WebIQ")
    tools.append(
        client.get_mcp_tool(
            name="Web IQ",
            url=os.getenv("WEB_IQ_MCP_URL", "https://api.microsoft.ai/v3/mcp"),
            project_connection_id=web_conn,
            approval_mode="never_require",
        )
    )

    # 2) Foundry IQ — knowledge-base MCP (Azure AI Search)
    foundry_conn = os.getenv("FOUNDRYIQ_CONNECTION_ID")
    foundry_url = os.getenv("FOUNDRYIQ_MCP_URL")
    if foundry_conn and foundry_url:
        tools.append(
            client.get_mcp_tool(
                name="Foundry IQ",
                url=foundry_url,
                project_connection_id=foundry_conn,
                approval_mode="never_require",
            )
        )

    # 3) Fabric IQ — Fabric Data Agent (structured supplier analytics). Resolves as the
    #    agent-user via the connection passthrough under the OBO credential.
    fabric_conn = os.getenv("FABRIC_CONNECTION_ID")
    if fabric_conn:
        tools.append(
            {
                "type": "fabric_dataagent_preview",
                "fabric_dataagent_preview": {
                    "project_connections": [{"project_connection_id": fabric_conn}]
                },
            }
        )

    # 4) Work IQ — mailbox / chat. Foundry cannot server-side-OBO the ai.azure.com token
    #    onward to Work IQ, so attach a Work IQ-audience OBO token as the tool header
    #    (the same pattern the autopilot uses).
    work_url = os.getenv("WORK_IQ_MCP_URL", "https://workiq.svc.cloud.microsoft/mcp")
    try:
        work_token, _ = obo.token_for(WORK_IQ_SCOPE)
        tools.append(
            client.get_mcp_tool(
                name="Work IQ",
                url=work_url,
                headers={"Authorization": f"Bearer {work_token}"},
                approval_mode="never_require",
            )
        )
    except Exception:  # noqa: BLE001
        logger.exception("Work IQ token exchange failed at startup; Work IQ tool not attached")

    logger.info("Built agent with %d IQ tool(s) [endpoint=%s model=%s]", len(tools), project_endpoint, model)

    return Agent(
        client=client,
        name="caldova-supply-foundry",
        description="Caldova supplier-assurance analyst wired to Foundry, Fabric, Web and Work IQ.",
        instructions=_load_instructions(),
        default_options={"store": False},
        tools=tools,
    )


def main() -> None:
    port = int(os.getenv("PORT", "8088"))
    host = os.getenv("HOST", "0.0.0.0")
    agent = build_agent()
    logger.info("Starting Caldova Supply Foundry agent (responses protocol) on %s:%d", host, port)
    ResponsesHostServer(agent).run(host=host, port=port)


if __name__ == "__main__":
    main()
