# Demo 1 — Web IQ (Microsoft Foundry portal Playground)

> Recording: _add link_ · Target length: ~3–4 min

## What this demo shows

The Foundry Hosted Agent answers a question about the **outside world**, grounded in
the live web via **Web IQ** — with no custom search code — and you can watch the Web IQ
tool fire in **Traces**, then see exactly how it's wired in the code.

## Where the demo happens

| You will… | In… |
|---|---|
| **Chat** the agent + show **Traces** | Microsoft Foundry portal — Playground |
| **Show** the Web IQ surface | Web IQ MCP endpoint |
| **Show** the code | VS Code — `src/foundry-hosted-agent/src/main.py` |

## Before you start

> New environment? Deploy the Foundry Hosted Agent first — see
> [`../../src/foundry-hosted-agent/README.md`](../../src/foundry-hosted-agent/README.md).

- `caldova-supply-hosted-agent` is deployed and healthy.
- You're signed into the Microsoft Foundry portal.

---

## Steps

1. **Playground** — in `caldova-supply-hosted-agent`, ask:
   > Any weather or carrier disruptions this week that could affect cold-chain shipments?

   The answer names **current, real-world events** (storms, carrier delays) dated to
   **this week** — which no stored data could produce.
2. Open the **Traces** tab and show the **Web IQ** tool call.
3. **Show the Web IQ surface** — the Web IQ MCP endpoint
   (`https://api.microsoft.ai/v3/mcp`). Point out Web IQ is a hosted **MCP** tool the
   agent calls; nothing was scraped or cached.
4. **VS Code** → `src/foundry-hosted-agent/src/main.py` (**L79–88**) → `# 1) Web IQ` →
   `client.get_mcp_tool(name="Web IQ", …, project_connection_id="WebIQ")`.
   > "One hosted MCP tool on the Web IQ connection — Microsoft Foundry runs the loop,
   > so the call shows up in Traces."

## Questions used

| Ask | Source |
|---|---|
| Any weather or carrier disruptions this week that could affect cold-chain shipments? | Web IQ |
| (alt) Any recent FDA recalls or regulatory notices affecting cold-chain biologics? | Web IQ |

## Transcript

_Add the final voice-over transcript here after recording._
