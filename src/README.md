# Source

The **Caldova supply-assurance agent** — a Foundry **hosted** Agent 365 autopilot that calls the
Azure OpenAI **Responses API** and attaches the four Microsoft IQs as project-connection tools.

## Layout

- [`agent/`](agent/) — the agent runtime:
  - `agent.py` — core logic; `_load_iq_tools` wires **Web IQ + Foundry IQ + Work IQ + Fabric IQ**;
    `_acquire_responses_bearer` performs the agentic-user OBO token exchange (see
    [`../infra/a365/README.md`](../infra/a365/README.md) for the identity model).
  - `host_agent_server.py` — the M365 Agents SDK host (Teams **activity** protocol) that also
    serves the OpenAI-compatible **`/responses`** endpoint for the Foundry Playground / VS Code
    Foundry Toolkit.
  - `responses_protocol.py` — the `/responses` (Responses protocol) handler; runs the agent's
    app-identity path (Web IQ + Foundry IQ) so it's chattable in Foundry without a twin agent.
  - `instructions.md` — the agent's domain system prompt (Caldova supplier-assurance analyst;
    enforces the IQ boundary — numbers → Fabric IQ, documents → Foundry IQ).
  - `ToolingManifest.json` — Work IQ MCP server declaration.
  - `foundry-infra/Dockerfile` — container image (ACR-built, no local Docker needed).
  - `requirements.txt` — runtime dependencies.

## How the four IQs are attached

Each IQ is a **Foundry project-connection** reference on the Responses call — the connection
carries auth, so the call targets `IQ_PROJECT_ENDPOINT`. Web IQ + Foundry IQ resolve under the
agent's app identity; Work IQ + Fabric IQ resolve under the agentic-user **OBO** token. See
`agent.py → _load_iq_tools` and `_acquire_responses_bearer`, and `.env.example` for the
connection references.
