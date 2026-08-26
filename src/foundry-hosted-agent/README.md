# Caldova Supply — Foundry Hosted Agent (Microsoft Foundry portal)

A **self-contained Foundry Hosted Agent** for the Caldova supplier-assurance
scenario, built to be **demoed live in the Microsoft Foundry portal** (Agents list +
Playground). It is deliberately kept separate from the Teams / Agent 365
**autopilot** in [`../autopilot`](../autopilot) so the two never mix. It is deployed
**into the same Microsoft Foundry project as its four Microsoft IQ connections**
(`4iq-foundry-project`), so each Microsoft IQ tool call is visible in the **Traces**
tab.

| | Foundry Hosted Agent (`caldova-supply-hosted-agent`) | Autopilot (`caldova-supply-autopilot`) |
|---|---|---|
| Folder | `src/foundry-hosted-agent/` | `src/autopilot/` |
| Runtime | `agent-framework` — Microsoft Foundry runs the tool loop | hand-rolled Responses API loop |
| Surface | **Microsoft Foundry portal Playground** | Microsoft Teams |
| Microsoft IQ | **All 4** (Web IQ, Foundry IQ, Fabric IQ, Work IQ) | All 4 |
| Hired into Teams? | **No** (stays a Foundry Hosted Agent in the portal) | Yes |
| Use in the talk | Demos 1 & 2 (grounding + Fabric in the portal) | Demo 3 (governed autopilot in Teams) |

Because it is **never hired into Teams**, its inline **Playground stays enabled** —
which is exactly what the autopilot cannot offer once it is published to Teams.

## Microsoft IQ coverage and identity — all four IQs, real data

All four Microsoft IQs are exposed through **one Microsoft Foundry toolbox**
(`caldova-supply-tools`). The container authenticates with its own **managed identity**,
and Microsoft Foundry runs the toolbox with **auth passthrough** — so the user-delegated
IQs resolve as the **signed-in Playground user** (no manual token exchange, no secrets):

- **Fabric IQ** — a `fabric_iq_preview` tool on a `UserEntraToken` connection to the
  Fabric Data Agent MCP endpoint → resolves as **you**.
- **Work IQ** — an `mcp` tool on the `UserEntraToken` `WorkIQ` connection → reads **your**
  mailbox (one-time consent in the Playground).
- **Foundry IQ** + **Web IQ** — `mcp` tools on their project connections, over the same call.

The toolbox (and the `fabric-iq-caldova` connection it needs) are provisioned by
[`infra/scripts/create-toolbox.ps1`](infra/scripts/create-toolbox.ps1). The agent code
([`src/main.py`](src/main.py)) is a **single `FoundryToolbox`** reference — every Microsoft
IQ tool call still shows in the **Traces** tab.

## Layout

```
src/foundry-hosted-agent/
  azure.yaml                      # hosted-agent service shape (responses protocol)
  src/
    main.py                       # agent-framework host: FoundryChatClient + Agent + ResponsesHostServer
    obo.py                        # agentic OBO — mints agent-user tokens (3-leg exchange)
    instructions.md               # supplier analyst prompt (4-IQ routing)
    requirements.txt              # agent-framework-foundry(+hosting), azure-identity, httpx
    Dockerfile                    # tiny python:3.12-slim image
    .env.example                  # local-run / config template
  infra/scripts/
    deploy.ps1                    # one-command deploy (build → create → grant → retire old)
    build-image-acr.ps1           # ACR cloud build of caldova-supply-hosted-agent:latest
    create-agent-version.ps1      # create the hosted agent version (Responses, Entra, no Teams)
    grant-fabric-and-iq-access.ps1# grant the instance identity IQ + Fabric access
```

## Architecture — Foundry runs the loop (native traces)

This is the **classic Foundry hosted-agent** shape: the container uses
**`agent-framework`** (`FoundryChatClient` + `Agent` + `ResponsesHostServer`), so
**Foundry itself runs the model + IQ tool loop**. That means the portal Playground
chats with it AND the **Traces tab shows each IQ tool call by name** (Fabric IQ, Web
IQ, Work IQ, Foundry IQ) — there is no hand-rolled Responses-API loop.

The four IQs are attached as Foundry **hosted tools**:
- **Web IQ / Foundry IQ / Work IQ** → `client.get_mcp_tool(project_connection_id=…)`
- **Fabric IQ** → a `fabric_dataagent_preview` tool referencing the Fabric connection

> The previous hand-rolled Responses-API build is kept locally in
> `src-responses-loop.bak/` for reference.

## Deploy

Prereqs: `az login`, the autopilot repo already provisioned (so its azd env holds
the account / ACR / IQ connection ids), and the Fabric workspace GUID behind the
Caldova Fabric Data Agent.

```powershell
cd src/foundry-hosted-agent
# One-time: create a client secret on the agent-identity blueprint used for OBO
#   az ad app credential reset --id <OboBlueprintClientId> --append
./infra/scripts/deploy.ps1 `
  -FabricWorkspaceId "<caldova-fabric-workspace-guid>" `
  -OboBlueprintClientId "<agent-identity blueprint app id>" `
  -OboBlueprintSecret   "<blueprint client secret>" `
  -OboInstanceClientId  "<ServiceIdentity SP id>" `
  -OboAgentUserId       "<agent-user object id>"
```

This builds the image, creates the `caldova-supply-hosted-agent` agent, and configures
**agentic OBO** so the agent authenticates as the provisioned agent-user — making all
four IQs return real data. The OBO identities default to the Caldova autopilot's
provisioned identities (blueprint / ServiceIdentity / agent-user), so the standalone
agent reuses the same real mailbox + Fabric access without a separate hire.

> Deploy is script-based (not `azd up`) because the `azure.ai.agents` azd extension
> is pinned to an incompatible preview in this environment — the same reason the
> autopilot uses REST scripts. When the extension is compatible again, `azd deploy`
> against `azure.yaml` becomes an option.

## Demo it

1. Open the **hosting Foundry project** in the portal → **Agents** → `caldova-supply-hosted-agent`.
2. Use the **Playground** and try, e.g.:
   - *Foundry IQ*: "What does Caldova's cold-chain excursion policy require?"
   - *Fabric IQ*: "Rank our CMOs by OTIF and flag any with an open regulatory action."
   - *Web IQ*: "Any recent Chicago-area shipping disruptions that could delay a cold-chain shipment?"

## Local run

```powershell
cd src/foundry-hosted-agent/src
Copy-Item .env.example .env   # fill in the values
python main.py
# POST http://localhost:8088/responses  { "input": "…", "stream": true }
```
