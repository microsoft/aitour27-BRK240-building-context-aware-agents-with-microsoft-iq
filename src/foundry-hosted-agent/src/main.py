# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

"""Caldova Supply — Microsoft Foundry Hosted Agent (agent-framework).

Microsoft Foundry runs the model + tool loop (via ``FoundryChatClient`` +
``ResponsesHostServer``), so the portal Playground chats with it AND the **Traces tab
shows each Microsoft IQ tool call by name**.

The four Caldova IQs are exposed through **one Microsoft Foundry toolbox**
(``caldova-supply-tools``) — Fabric IQ (``fabric_iq_preview``), Work IQ, Foundry IQ and
Web IQ. The container authenticates with its own **managed identity**, and Microsoft
Foundry runs the toolbox with **auth passthrough**, so the user-delegated IQs (Fabric,
Work IQ) resolve as the **signed-in Playground user**. Each Microsoft IQ tool call shows
in the **Traces** tab.

Story: **Foundry Hosted Agent + 4 Microsoft IQs** — independent of the Teams autopilot.
"""

from __future__ import annotations

import logging
import os

from agent_framework import Agent
from agent_framework.foundry import FoundryChatClient
from agent_framework_foundry_hosting import FoundryToolbox, ResponsesHostServer
from azure.identity import DefaultAzureCredential, ManagedIdentityCredential

from workiq_consent import enable_work_iq_consent_handling

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("main")


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

    # The container authenticates to the Microsoft Foundry project with its own managed
    # identity. All four Microsoft IQs are exposed through **one Foundry toolbox**
    # (``caldova-supply-tools``): Microsoft Foundry runs the toolbox with **auth
    # passthrough**, so Fabric IQ and Work IQ resolve as the **signed-in Playground
    # user** (Web IQ + Foundry IQ over the same call). No manual token exchange.
    instance_client_id = os.getenv("FOUNDRY_AGENT_DEFAULT_INSTANCE_CLIENT_ID")
    credential = (
        ManagedIdentityCredential(client_id=instance_client_id)
        if instance_client_id
        else DefaultAzureCredential()
    )

    client = FoundryChatClient(
        project_endpoint=project_endpoint,
        model=model,
        credential=credential,
        allow_preview=True,
    )

    toolbox_name = os.getenv("CALDOVA_TOOLBOX_NAME", "caldova-supply-tools")
    toolbox_url = f"{project_endpoint.rstrip('/')}/toolboxes/{toolbox_name}/mcp?api-version=v1"
    toolbox = FoundryToolbox(
        credential=credential,
        url=toolbox_url,
        name="caldova_supply_toolbox",
        load_prompts=False,
    )
    logger.info("Built agent with Microsoft Foundry toolbox: %s", toolbox_url)

    return Agent(
        client=client,
        name="caldova-supply-hosted-agent",
        description="Caldova supplier-assurance analyst wired to Web, Foundry, Fabric and Work IQ.",
        instructions=_load_instructions(),
        default_options={"store": False},
        tools=[toolbox],
    )


def main() -> None:
    port = int(os.getenv("PORT", "8088"))
    host = os.getenv("HOST", "0.0.0.0")
    enable_work_iq_consent_handling()
    agent = build_agent()
    logger.info("Starting Caldova Supply Foundry agent (responses protocol) on %s:%d", host, port)
    ResponsesHostServer(agent).run(host=host, port=port)


if __name__ == "__main__":
    main()
