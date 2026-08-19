# Publish `caldova-supply-autopilot` as an Agent 365 autopilot (digital worker)

The hosted agent is built and created by the **deploy** step
(`scripts/post-provision.ps1`, run by `azd provision`). These scripts perform the
separate **Agent 365 registration** on top of the already-deployed agent, so it
shows up in the **Agent 365 registry** and can be hired as a digital worker in
Microsoft Teams. This mirrors the iqdeepdive autopilot's `infra/a365` flow.

## Model: auto-create blueprint

Unlike the older approach, the agent identity **blueprint is not pre-created** in
bicep. It is **auto-created by the hosted-agent version-create** (the deploy step
omits `blueprint_reference`). Because the container bakes the blueprint client id
at build time, the deploy step runs two passes (build placeholder → create version
→ rebuild with the real ids → create version). The resulting
`AGENT_IDENTITY_BLUEPRINT_ID`, `AGENT_INSTANCE_CLIENT_ID`, and `AGENT_GUID` are
written to the azd environment for this orchestrator to read.

## What it does

| Step | Script | Effect |
| ---- | ------ | ------ |
| 0 | `enable-activity-protocol.ps1` | Re-assert the **`activity`** protocol + **`BotServiceRbac`** auth on the agent endpoint. |
| 1 | (inline) | Register `Microsoft.BotService` provider (idempotent). |
| 2 | `botservice.bicep` | Deploy an **Azure Bot Service** (`msaAppId` = auto-created blueprint id, endpoint = the agent's `activityProtocol` endpoint) + Teams channel. |
| 3 | `publish-digital-worker.ps1` | POST the **Microsoft 365 publish** request → pending blueprint in the M365 admin center. |
| 4 | `create-blueprintsp-oauth2-grants.ps1` | Grant the blueprint SP the delegated scopes the four IQs need (see **Four-IQ OBO grants** below). |
| 5 | `add-current-user-as-blueprint-owner.ps1` | Add you as an owner of the blueprint app. |

## Four-IQ OBO grants (why all four IQs resolve)

Web IQ and Foundry IQ resolve under the agent's **app identity**. **Work IQ** and
**Fabric IQ** are user-delegated, so the agent forwards an **agentic-user OBO token**
(exchanged for `https://ai.azure.com`) as the top-level Responses bearer. For that
exchange to succeed, `create-blueprintsp-oauth2-grants.ps1` grants the blueprint SP
(admin consent, `AllPrincipals`) the delegated scopes a working autopilot blueprint
holds:

| Resource | Scopes | Enables |
|:---|:---|:---|
| Microsoft Graph | `Mail.ReadWrite Mail.Send Chat.ReadWrite User.Read.All Sites.Read.All Files.ReadWrite.All ChannelMessage.Read.All ChannelMessage.Send` | Work IQ (mail/chat/files) |
| Azure Machine Learning | `user_impersonation` | the `ai.azure.com` token (the OBO exchange) |
| Power Platform API | `Connectivity.Connections.Read` | Fabric / connection resolution |
| Agent Tools + Messaging Bot API | MCP scopes + `AgentData.ReadWrite` | A365 tool/data plane |

> If OBO can't be obtained, the agent **degrades gracefully** — it drops Work IQ +
> Fabric IQ for that turn (so the call doesn't 400) and answers with Web IQ + Foundry IQ.

## Post-hire access (run after hiring the instance in Teams)

The instance identity and the agent-user account only exist **after** you hire the
instance, and (in this sample) the IQ connections live in a **separate** project.
Run once after hiring:

```powershell
./infra/a365/grant-iq-project-access.ps1 `
  -IqAccountResourceId "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<iq-account>" `
  -FabricWorkspaceId "<fabric-workspace-guid>"
```

It grants **Cognitive Services User** on the IQ project to both the **instance
identity** (app path) and the **agent user** (OBO path — the Responses call runs as
this user), and adds the agent user as a **Member** of the Fabric workspace backing
the Fabric IQ data agent. Without these, Work IQ/Fabric return nothing (or 401/403)
even when the OBO exchange succeeds.

## Run it

```powershell
# Prereqs: Owner/Contributor on the resource group, az + azd logged in,
#          an Agent 365 / Copilot license in the tenant.
./infra/a365/publish-autopilot.ps1
```

Use `-WhatIf` to print resolved values without making changes, `-SkipBotService`
if the bot already exists.

## After publishing

1. **Admin approval** — an AI Administrator / Global Administrator approves the
   pending blueprint at
   [admin.cloud.microsoft/#/agents/all/requested](https://admin.cloud.microsoft/?#/agents/all/requested).
2. **Wire the backend (Bot ID)** — in the portal UI open
   `https://dev.teams.microsoft.com/tools/agent-blueprint/<blueprintId>` →
   **Configuration** → set **Bot ID** = the blueprint client id → **Save**. The
   API equivalent (`configure-blueprint-backend.ps1`) usually returns **403**, so
   the portal UI is the reliable path.
3. **Use it in Teams** — Apps → **Agents for your team** → find
   `caldova-supply-autopilot` → create an instance, then test the four IQs:
   order/shipment (**Fabric IQ**), supply policy (**Foundry IQ**), mailbox
   (**Work IQ**, on-behalf-of the signed-in user), and real-time web (**Web IQ**).

## Cross-project IQ note

The four IQ connections live in your **Foundry IQ project**, while
`azd provision` creates a *separate* Foundry account/project for hosting. The agent's
Responses call targets `IQ_PROJECT_ENDPOINT`, so the instance identity must have
access there — grant it **Cognitive Services User** on the Foundry IQ project and,
for Work IQ/Fabric OBO, ensure the blueprint SP has the required delegated grants
(see `create-blueprintsp-oauth2-grants.ps1`).
