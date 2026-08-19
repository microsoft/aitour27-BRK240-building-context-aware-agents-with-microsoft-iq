# Setup — deploy the Caldova Supply Autopilot

> A **hosted** Foundry agent, wired to all **four IQs**, deployed with Azure
> Developer CLI and published as an **Agent 365 autopilot** (digital worker).
>
> The agent code calls the Responses API and attaches the IQ tools inline — there is
> **no prompt agent to create and wrap**. It targets the agent name
> `caldova-supply-autopilot`.

## 🧠 The four IQs

The agent attaches these tools on every Responses API turn (see
`src/agent/agent.py` → `_load_iq_tools`). Every IQ is a **Foundry
project-connection reference** — the connection carries auth, so the Responses call
must target the project endpoint (`IQ_PROJECT_ENDPOINT`) for them to resolve. The
connection names are set by the seeding step (see [`../infra/README.md`](../infra/README.md))
and surfaced as env vars in `.env.example`.

| IQ | Responses API tool | Connection (`project_connection_id`) |
|----|--------------------|--------------------------------------|
| Web IQ (real-time web) | `mcp` → `api.microsoft.ai/v3/mcp` | `WebIQ` |
| Foundry IQ (knowledge base) | `mcp` → Azure AI Search KB | `caldova-supply-kb` |
| Work IQ (M365 email/chat) | `mcp` → `workiq.svc.cloud.microsoft/mcp` (`allowed_tools`: do_action/get_schema/fetch) | `WorkIQ` |
| Fabric IQ (supplier performance data) | `fabric_dataagent_preview` — the Caldova `SupplierDataAgent` | `caldova-supply-dataagent` |

- **Model:** a reasoning model deployment in your Foundry project (e.g. `gpt-5.4-mini`) with `reasoning.effort=low`.
- **Instructions:** the Caldova supplier-assurance prompt lives in
  `src/agent/instructions.md` (editable), wrapped with an A365
  hosting preamble (`{user_name}`, HTML formatting, prompt-injection guardrails). It
  enforces the IQ boundary — **numbers → Fabric IQ, documents → Foundry IQ**.

> **Reserved env-var names:** the hosting platform reserves every `FOUNDRY_*` env
> var (it injects its own, pointing at the *hosting* project). The agent therefore
> reads `IQ_PROJECT_ENDPOINT`, `IQ_REASONING_EFFORT`, and `FOUNDRYIQ_*` — do not
> rename these back to `FOUNDRY_*`.
>
> **Work IQ + Fabric need identity context:** the agent forwards an **agentic-user OBO
> token** (exchanged for `ai.azure.com`) as the top-level Responses bearer so Work IQ
> and Fabric resolve as the agent's governed identity. Web IQ and Foundry IQ also
> resolve under the agent's app identity.
>
> **Project note:** the four IQ connections live in your **Foundry IQ project**
> (`IQ_PROJECT_ENDPOINT`), which may be the same as, or separate from, the hosting
> project `azd provision` creates. If separate, the agent's instance identity must be
> granted **Cognitive Services User** (and connection access) on the IQ project so the
> Responses call and its tools resolve — see [`grant-iq-project-access.ps1`](../infra/a365/grant-iq-project-access.ps1).

---

## 📋 Prerequisites

**Note:** You must be enrolled in the [Frontier preview program](https://adoption.microsoft.com/en-us/copilot/frontier-program/) to publish a Foundry agent to Microsoft Agent 365.

Ensure you have the following installed:

| Requirement | Description |
|-------------|-------------|
| [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) | Infrastructure deployment tool |
| [Python 3.11+](https://www.python.org/downloads/) | Agent runtime (built and packaged inside the container image by ACR Build) |
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) | Used by the deploy + `infra/a365` scripts (ACR Build runs in the cloud — no local Docker required) |

### 🔐 Required Permissions

- **Owner** role on the Azure subscription
- **Azure AI User** or **Cognitive Services User** role at subscription or resource group level
- **Tenant Admin** role for organization-wide configuration

---

## 🚀 Quick Start

### Step 1: Authenticate

Login to your Azure tenant and authenticate with Azure Developer CLI. Depending on your tenant's security settings, `az login` alone may be sufficient, or you may need to additionally sign in for the specific scopes used by the deployment scripts.

```powershell
# Login to Azure CLI
az login

# Login to Azure Developer CLI
azd auth login
```

### Step 2: Deploy Everything

### Region availability

> This sample uses [Foundry hosted agents](https://learn.microsoft.com/azure/foundry/agents/quickstarts/quickstart-hosted-agent?pivots=azd). Your Foundry account and other resources must be in a region where hosted agents are available. At the time of writing, supported regions are:
>
> Australia East, Brazil South, Canada Central, Canada East, East US, East US 2, France Central, Germany West Central, Italy North, Japan East, Korea Central, North Central US, Norway East, Poland Central, South Africa North, South Central US, South India, Southeast Asia, Spain Central, Sweden Central, Switzerland North, UAE North, UK South, West Central US, West US, West US 3.

#### Optional: Customize Your Agent

Before deploying, you can customize:
- **Agent instructions:** [instructions.md](../src/agent/instructions.md) (loaded and wrapped with the A365 hosting preamble in `agent.py`)
- **The four IQs:** [agent.py](../src/agent/agent.py) → `_load_iq_tools` (connection references come from environment variables)
- **MCP tools:** [ToolingManifest.json](../src/agent/ToolingManifest.json) - [Learn more](https://learn.microsoft.com/en-us/microsoft-agent-365/tooling-servers-overview)

#### Deploy

This uses **ACR Build** (cloud build) — no local Docker required. Run:

```powershell
# 1) Provision the Foundry account/project/ACR and deploy the hosted agent.
#    (postprovision builds the image and creates the agent; the blueprint +
#    instance identity are auto-created by the version-create.)
azd provision

# 2) Register the deployed agent in Agent 365 (Bot Service + M365 publish + grants).
./infra/a365/publish-autopilot.ps1
```

After deployment completes, retrieve your resource values:

```powershell
azd env get-values
```

> **📌 What to expect:** `azd provision` deploys the hosted agent and auto-creates
> its **AgentIdentityBlueprint**. `./infra/a365/publish-autopilot.ps1` then submits
> the publish request, so the blueprint shows up as a **pending request** in the
> M365 admin center. You must approve it, set the Bot ID in the Teams Developer
> Portal, and create an instance before it is usable — see below and
> [infra/a365/README.md](./infra/a365/README.md).

### Step 3: Approve the Agent Blueprint

**Important:** The first step is to approve the **agent blueprint** itself. Agent instances will be created later in Step 5.

1. Navigate to the [Microsoft 365 admin center](https://admin.cloud.microsoft/?#/agents/all/requested)
2. Under **Requests**, locate your **agent blueprint** — the row whose name contains your agent name (`...caldova-supply-autopilot-...-AgentIdentityBlueprint`). Match it by the **Bot/App ID** (the blueprint client id from `azd env get-values` → `AGENT_IDENTITY_BLUEPRINT_ID`).

3. Click the **Approve request and activate** button to approve the blueprint.

### Step 4: Configure Teams Integration

After approving the agent blueprint, configure it in the Teams Developer Portal:

1. Open the [Teams Developer Portal](https://dev.teams.microsoft.com/tools/agent-blueprint) and locate your approved agent blueprint
    
   **Note:** Only 100 Agent Blueprints are displayed. If yours isn't visible, click any blueprint to open its details page, then in the browser's address bar replace the blueprint ID portion of the URL with your own Blueprint ID from the previous step (for example: `https://dev.teams.microsoft.com/tools/agent-blueprint/<your-blueprint-id>`).

2. Get your Blueprint ID:
   ```powershell
   azd env get-values   # AGENT_IDENTITY_BLUEPRINT_ID
   ```

3. Navigate to **Configuration** and add your **Bot ID** (same as the Blueprint ID / `AGENT_IDENTITY_BLUEPRINT_ID`).

### Step 5: Create Agent Instances

After configuring the agent blueprint in Teams Developer Portal, you can now create agent instances based on your blueprint:

1. In Microsoft Teams, navigate to **Apps** → **Agents for your team**
2. Find your agent blueprint and create an instance. Hiring an instance consumes a Microsoft 365 Frontier / AI Teammates license and sets you as its manager.

---

## 🏗️ Architecture Overview

The flow has two phases: a **deploy** phase (`azd provision` → `scripts/post-provision.ps1`) and an
**Agent 365 registration** phase (`./infra/a365/publish-autopilot.ps1`).

### 1️⃣ Provision a Foundry Project (deploy)

`infra/main.bicep` creates only the Foundry account + project + Azure Container Registry. There is
**no pre-created blueprint** — the agent identity blueprint and instance identity are auto-created
later by the version-create.

### 2️⃣ Build the image + create the hosted agent (deploy)

`scripts/post-provision.ps1` builds the container with **ACR Build** (cloud, no local Docker) and
creates the hosted agent via the versions API, **omitting `blueprint_reference`** so the platform
auto-creates the blueprint + instance identity. Because the image bakes the blueprint client id at
build time, this runs two passes (placeholder → real ids) and rolls `@latest` forward.

### 3️⃣ Enable the activity protocol (registration)

`infra/a365/enable-activity-protocol.ps1` re-asserts the Teams `activity` protocol + `BotServiceRbac`
auth on the agent endpoint.

### 4️⃣ Deploy the Azure Bot Service (registration)

`infra/a365/botservice.bicep` creates the Bot Service (relay between Teams and the agent) with
`msaAppId` = the auto-created blueprint id and the agent's `activityProtocol` endpoint, plus a Teams
channel. This runs **after** deploy because the blueprint id doesn't exist until the agent is created.

### 5️⃣ Publish to your organization (registration)

`infra/a365/publish-digital-worker.ps1` publishes the agent to Microsoft 365 as a hireable digital
worker, then the OAuth2 grants + blueprint-owner scripts finish the setup.

> **⚠️ Important:** The agent requires [admin approval](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/review-admin-consent-requests#review-and-take-action-on-admin-consent-requests-1) before becoming available for hiring. See [infra/a365/README.md](./infra/a365/README.md).

---

## 📜 Hosted Agent Logs

If you receive an error, the response will include a `FOUNDRY_AGENT_SESSION_ID`. Use it to stream the hosted agent's session logs:

```bash
curl -N \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: text/event-stream" \
  -H "Cache-Control: no-cache" \
  -H "Foundry-Features: HostedAgents=V1Preview" \
  "https://$ACCOUNT_NAME.services.ai.azure.com/api/projects/$PROJECT_NAME/agents/$AGENT_NAME/sessions/$SESSION_NAME:logstream?api-version=2025-11-15-preview"
```

---

## 📖 Additional Resources

- [Foundry Container Agents Documentation](https://github.com/microsoft/container_agents_docs)
- [Azure Developer CLI Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [Agent Blueprint Configuration](https://dev.teams.microsoft.com/tools/agent-blueprint)

---

## 🤝 Support

For issues or questions, please refer to the official documentation or contact your Azure administrator.

