# Attendee instructions — Caldova Supply Autopilot

Step-by-step guidance to build, deploy, and explore the **Caldova Supply Autopilot**:
a context-aware **Agent 365 autopilot** grounded across all four Microsoft IQs.

> Prefer to follow the live session? These same steps back the on-stage demos in
> [`../delivery-resources/demos/README.md`](../delivery-resources/demos/README.md).

## What you'll build

One hosted Foundry agent, wired to all four IQs on Caldova's supplier data:

| IQ | Grounds the agent in |
|---|---|
| **Web IQ** | Live web context (weather, carrier, news) |
| **Foundry IQ** | Caldova documents — policies, contracts, quality/inspection reports |
| **Fabric IQ** | Supplier performance numbers — OTIF, quality, regulatory, audit, financial |
| **Work IQ** | The agent's Microsoft 365 mailbox (read + reply) |

## Prerequisites

- An Azure subscription (**Owner**) and **tenant admin** for the Agent 365 publish.
- Enrollment in the [Frontier preview program](https://adoption.microsoft.com/en-us/copilot/frontier-program/) (required to publish a Foundry agent to Agent 365).
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd), [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), [Python 3.11+](https://www.python.org/downloads/), and [`uv`](https://docs.astral.sh/uv/).
- A Microsoft Fabric workspace (with capacity) and an Azure AI Search service.

## Steps

### 1. Authenticate

```powershell
az login
azd auth login
```

### 2. Provision + seed + deploy

Follow [`../docs/setup.md`](../docs/setup.md) for the full flow. In short:

```powershell
# opt in to seeding the four IQs + registering their connections during provision
azd env set SEED_IQ_ON_PROVISION 1
azd env set TENANT_ID <tenant-guid>
azd env set FABRIC_WORKSPACE_ID <workspace-guid>
azd env set AZURE_AI_SEARCH_SERVICE_ENDPOINT https://<search>.search.windows.net

pip install -r infra/scripts/seed-requirements.txt
azd up                                    # provision -> seed + connect -> deploy
./infra/a365/publish-autopilot.ps1        # Agent 365 registration
```

This builds the Fabric supplier analytics + `SupplierDataAgent`, the `caldova-supply-kb`
knowledge base (four sources), and the hosted agent. See
[`../infra/README.md`](../infra/README.md) for details and the by-hand path.

### 3. Publish the ontology (one-time, preview)

The Fabric IQ ontology's graph build is a portal step today:

1. Fabric → open **`CaldovaSupplierOntology`** → **Publish**.
2. Open **`SupplierDataAgent`** → **Add data source** → select the ontology.

See [`../docs/supplier-ontology.md`](../docs/supplier-ontology.md). The demo works
without this — `SupplierSM` already answers the relationship questions.

### 4. Approve + hire the agent

1. Approve the agent blueprint in the [Microsoft 365 admin center](https://admin.cloud.microsoft/?#/agents/all/requested).
2. Set the **Bot ID** in the [Teams Developer Portal](https://dev.teams.microsoft.com/tools/agent-blueprint).
3. In Teams → **Apps → Agents for your team**, create (hire) an instance.

(Full detail in [`../docs/setup.md`](../docs/setup.md) and [`../infra/a365/README.md`](../infra/a365/README.md).)

### 5. Try it

Chat with the deployed agent (VS Code **Foundry Toolkit**, or in Teams once hired).
Ask one question at a time:

- **Web IQ** — *Any weather or carrier disruptions this week that could affect cold-chain shipments?*
- **Foundry IQ** — *Is a major cold-chain excursion eligible for replacement and credit?*
- **Fabric IQ** — *Rank suppliers by OTIF and flag any with open regulatory actions.*
- **Foundry IQ** — *Why was Summit Dose awarded CALD-201?*
- **Work IQ** (in Teams) — *Any urgent supply escalations in your mailbox?*

## Learn more

- [Setup / deploy reference](../docs/setup.md)
- [Fabric IQ ontology](../docs/supplier-ontology.md)
- [Demo flows](../delivery-resources/demos/README.md)
- [The Caldova data corpus](../data/README.md)
