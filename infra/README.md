# Infrastructure

Deployment and seeding for the Caldova supplier-assurance agent. The flow has two phases —
**deploy** (`azd provision`) and **Agent 365 registration** (`infra/a365/publish-autopilot.ps1`) —
plus **automated seeding** so anyone can replicate the demo.

## Layout

- `main.bicep` + `modules/` — provisions the Foundry account/project + Azure Container Registry.
- `scripts/` — the deploy phase:
  - `post-provision.ps1` — orchestrates seeding + the two-pass build & hosted-agent version-create.
  - `build-docker-image-acr.ps1` — cloud image build (ACR, no local Docker).
  - `agent-creation-script.ps1` — creates the hosted agent (auto-creates the blueprint + instance identity; declares the `activity` + `responses` protocols).
- `a365/` — Agent 365 registration (Bot Service, M365 publish, OBO grants, post-hire IQ access).
  See [`a365/README.md`](a365/README.md).

## Automated seeding (Caldova corpus → the four IQs)

Seeding pulls the Caldova supplier corpus (see [`../data/README.md`](../data/README.md)) and builds:

- **Fabric IQ** — provisions the `CaldovaSupplierAnalytics` lakehouse (14 Delta tables), the
  `CaldovaMedicinalProductOntology` ontology, the `SupplierSM` semantic model, the
  `Supplier Performance` report, and `SupplierDataAgent` — all from the official dataset.
  The Data Agent is attached to **both** `SupplierSM` and the ontology.
- **Foundry IQ** — builds the `caldova-supply-kb` knowledge base with four sources: **policies**,
  **procurement**, **quality**, and **cold-chain**.
- **Web IQ + Work IQ** — connection references only (no data to seed).

## Seeding scripts

The seed data lives in [`../data`](../data). The scripts under `scripts/` build it:

| Script | What it does |
|:---|:---|
| `../data/caldova-upstream/provision/fabric/*.py` | Provision Fabric IQ in dependency order: `create_fabric_lakehouse` → `create_fabric_ontology` → `create_fabric_semantic_model` → `create_fabric_reports` → `create_fabric_data_agent` (`uv`-based). The ontology must precede the Data Agent, which needs `FABRIC_ONTOLOGY_ID`. |
| `refresh-ontology-graph.py` | Builds (refreshes) the ontology graph after `create_fabric_ontology.py`. Without it the graph is empty and the Data Agent reports the graph model as unavailable. Idempotent — see [`../docs/ontology.md`](../docs/ontology.md). |
| `seed-foundryiq.py` | Creates the Azure AI Search index over `data/knowledge-base/*.md`, uploads the policy chunks, and creates the `caldova-supply-kb` knowledge base (agentic retrieval + answer synthesis). |
| `seed-foundryiq-docs.py` | Builds the **procurement / quality / cold-chain** document knowledge sources from the `caldova-upstream` PDFs/JSON and attaches them to `caldova-supply-kb`. |
| `seed-connections.ps1` | Registers the Foundry project connections (Foundry IQ KB, `SupplierDataAgent`, Work IQ, optional Web IQ). Returns the connection resource ids; `-SetAzdEnv` also persists them to the azd env. |
| `seed.ps1` | Orchestrator that runs all data seeders (the five Fabric provision scripts + Foundry IQ). |
| `seed-and-connect.ps1` | End-to-end: runs `seed.ps1`, discovers the `SupplierDataAgent` GUID by name, then registers all four project connections. Reads its inputs from the azd env; `-SetAzdEnv` writes the connection ids back so `azd up` bakes them into the agent. |

```powershell
# Prereqs: az login; uv installed; pip install -r infra/scripts/seed-requirements.txt
# azd env has TENANT_ID, FABRIC_WORKSPACE_ID, AZURE_AI_SEARCH_SERVICE_ENDPOINT
./infra/scripts/seed.ps1

# then register the project connections (SupplierDataAgent is discovered by name):
./infra/scripts/seed-connections.ps1 `
  -SubscriptionId <sub> -ResourceGroup <rg> -AccountName <foundry-account> `
  -ProjectName <foundry-project> -SearchEndpoint https://<search>.search.windows.net `
  -FabricWorkspaceId <ws-guid> -FabricDataAgentId <SupplierDataAgent-guid> [-WebIqApiKey <key>]
```

After seeding, set the agent env vars (`FOUNDRYIQ_CONNECTION_ID`/`FOUNDRYIQ_MCP_URL`,
`FABRIC_CONNECTION_ID`, `WORK_IQ_CONNECTION_ID`, `WEB_IQ_CONNECTION_ID`) — see
[`../src/autopilot/.env.example`](../src/autopilot/.env.example).

> **Validated live (end to end):** the Fabric provision scripts build the supplier lakehouse
> (15 suppliers, 1,575 weekly performance rows) and publish `SupplierDataAgent`, which answers
> supplier questions (OTIF ranking, region grouping). `seed-foundryiq.py` + `seed-foundryiq-docs.py`
> build the four-source KB and answer grounded, cited policy/procurement/quality questions.
> `seed-connections.ps1` registers the Foundry IQ, Fabric, and Work IQ connections; **Web IQ**
> needs your own `api.microsoft.ai` subscription key (`-WebIqApiKey`).
>
> **Fabric IQ / Foundry IQ boundary:** numbers (OTIF, quality, regulatory, audit, financial) go to
> Fabric IQ; documents (policies, contracts, inspection reports) go to Foundry IQ. The agent's
> `instructions.md` enforces this so the two IQs never overlap.

## One-command replication

`azd up` provisions the Foundry account/project + ACR, then the `postprovision` hook
(`post-provision.ps1`) builds the container and creates the hosted agent. Set
**`SEED_IQ_ON_PROVISION=1`** first to also seed the four IQs and register their project
connections *before* the build, so the agent bakes in the Caldova connection ids:

```powershell
azd env set SEED_IQ_ON_PROVISION 1          # opt in to live IQ seeding + connection registration
# the seeders need these in the azd env (Search + Fabric are pre-existing resources):
azd env set TENANT_ID <tenant-guid>
azd env set FABRIC_WORKSPACE_ID <workspace-guid>
azd env set AZURE_AI_SEARCH_SERVICE_ENDPOINT https://<search>.search.windows.net
# optional: your own api.microsoft.ai key enables the Web IQ connection
azd env set WEB_IQ_API_KEY <key>

pip install -r infra/scripts/seed-requirements.txt   # + uv, for the Fabric provision scripts
azd up                                        # provision -> seed + connect -> deploy
./infra/a365/publish-autopilot.ps1            # Agent 365 registration
./infra/a365/grant-iq-project-access.ps1 -IqAccountResourceId <...> -FabricWorkspaceId <...>
```

Prefer to seed by hand (or re-run seeding without a full deploy)? Run the orchestrator
directly against the current azd env:

```powershell
pip install -r infra/scripts/seed-requirements.txt   # + uv
# az login first; SUBSCRIPTION_ID/RESOURCE_GROUP/ACCOUNT_NAME/PROJECT_NAME come from `azd env get-values`
./infra/scripts/seed-and-connect.ps1 -SetAzdEnv [-WebIqApiKey <key>]
```

> The Fabric IQ ontology needs no manual portal step: `create_fabric_ontology.py` creates
> `CaldovaMedicinalProductOntology` and `create_fabric_data_agent.py` attaches it to
> `SupplierDataAgent` alongside `SupplierSM`. See [`../docs/ontology.md`](../docs/ontology.md).
