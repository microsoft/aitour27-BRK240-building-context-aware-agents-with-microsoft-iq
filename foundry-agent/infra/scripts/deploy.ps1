#!/usr/bin/env pwsh
<#
.SYNOPSIS
  One-command deploy for the standalone `caldova-supply-hosted-agent` agent.

.DESCRIPTION
  Orchestrates the full deploy, independent of the autopilot:
    1. Build the container image with ACR Build.
    2. Create the hosted agent version (pass 1) -> auto-creates the instance identity.
    3. Create a second version (pass 2) with the instance client id pinned as a
       runtime env var so the container can authenticate as itself.
    4. Grant the instance identity Cognitive Services User on the IQ account +
       (optionally) Fabric workspace membership so all three IQs resolve.

  Config is read from the azd environment of THIS repo (the same env the autopilot
  uses), so no duplicate configuration is required. Values consumed:
    AZURE_AI_PROJECT_ENDPOINT, AZURE_CONTAINER_REGISTRY_ENDPOINT,
    FOUNDRY_PROJECT_ENDPOINT (-> IQ_PROJECT_ENDPOINT), FOUNDRY_MODEL_NAME,
    FABRIC_CONNECTION_ID, FOUNDRY_IQ_CONNECTION_ID, FOUNDRY_IQ_MCP_URL,
    WEB_IQ_CONNECTION_ID.

.PARAMETER FabricWorkspaceId
  GUID of the Fabric workspace behind the Fabric Data Agent. Pass it to enable
  Fabric IQ under the agent's app identity. Omit to deploy with Web + Foundry IQ
  only (add Fabric membership later with grant-fabric-and-iq-access.ps1).
#>
param(
    [string]$FabricWorkspaceId,

    # ---- Agentic OBO (real user passthrough) --------------------------------------
    # The agent mints user-delegated tokens AS a provisioned Agent 365 agent-user (which
    # owns the demo mailbox + has Fabric access), using that agent's identity blueprint
    # secret + its ServiceIdentity as the federated instance. These default to the
    # Caldova autopilot's provisioned identities so the standalone agent reuses the same
    # real data. Create the blueprint secret once with:
    #   az ad app credential reset --id <OboBlueprintClientId> --append
    [string]$OboBlueprintClientId = $env:OBO_BLUEPRINT_CLIENT_ID,
    [string]$OboBlueprintSecret   = $env:OBO_BLUEPRINT_SECRET,
    [string]$OboInstanceClientId  = $env:OBO_INSTANCE_CLIENT_ID,   # ServiceIdentity SP object/app id
    [string]$OboAgentUserId       = $env:OBO_AGENT_USER_ID          # agent-user object id
)
$ErrorActionPreference = "Stop"

# --- Load azd environment values into $env: for the child scripts ---------------
Write-Host "Loading azd environment ..."
Push-Location "$PSScriptRoot/../../.."   # repo root (where the autopilot azure.yaml + .azure env live)
try {
    $envLines = azd env get-values
} finally {
    Pop-Location
}
foreach ($line in $envLines) {
    if ($line -match '^(?<k>[A-Za-z0-9_]+)="?(?<v>.*?)"?$') {
        Set-Item -Path "Env:$($Matches.k)" -Value $Matches.v
    }
}

# --- Standalone-specific settings ----------------------------------------------
$env:AGENT_NAME = "caldova-supply-hosted-agent"
# The container's Responses call targets the IQ project (where the 3 connections live).
$env:IQ_PROJECT_ENDPOINT = $env:FOUNDRY_PROJECT_ENDPOINT

# Derive the IQ project's AIServices account ARM id from the Fabric connection id
# (…/accounts/<acct>/projects/<proj>/connections/<name>).
if ($env:FABRIC_CONNECTION_ID -match '^(?<acct>/subscriptions/.+?/accounts/[^/]+)/projects/') {
    $env:IQ_ACCOUNT_RESOURCE_ID = $Matches.acct
} else {
    throw "Could not derive IQ_ACCOUNT_RESOURCE_ID from FABRIC_CONNECTION_ID."
}

# Fabric IQ is now called via its MCP endpoint with a Fabric APP token (works under
# app identity — the portal has no signed-in user to OBO). Derive the workspace + data
# agent ids from the existing Fabric connection's stored keys so the container can build
# the Fabric MCP URL. Falls back to the -FabricWorkspaceId param for the workspace id.
$fabConnName = ($env:FABRIC_CONNECTION_ID -replace '.*/connections/', '')
try {
    $fabSecrets = az rest --method post --url "https://management.azure.com$($env:IQ_ACCOUNT_RESOURCE_ID)/connections/$fabConnName/listSecrets?api-version=2025-06-01" 2>$null | ConvertFrom-Json
    $env:FABRIC_DATAAGENT_ID = $fabSecrets.properties.credentials.keys.'artifact-id'
    $wsFromConn = ($fabSecrets.properties.credentials.keys.'workspace-id') -replace '^/', ''
    if ($wsFromConn) { $env:FABRIC_WORKSPACE_ID = $wsFromConn }
} catch {
    Write-Host "Could not read Fabric connection secrets; using -FabricWorkspaceId only."
}
if (-not $env:FABRIC_WORKSPACE_ID -and $FabricWorkspaceId) { $env:FABRIC_WORKSPACE_ID = $FabricWorkspaceId }
Write-Host "Fabric MCP (app-identity): workspace=$($env:FABRIC_WORKSPACE_ID) dataAgent=$($env:FABRIC_DATAAGENT_ID)"

# Clear autopilot leftovers pulled in from the shared azd env so our create
# auto-creates ITS OWN agent-identity blueprint (never reuses the autopilot's).
Remove-Item Env:AGENT_BLUEPRINT_NAME     -ErrorAction SilentlyContinue
Remove-Item Env:AGENT_INSTANCE_CLIENT_ID -ErrorAction SilentlyContinue

# On re-runs, reuse THIS agent's own auto-created blueprint (discovered from an
# existing version) so we don't spin up a duplicate identity each deploy.
try {
    $discoverToken = az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv
    $dh = @{ Authorization = "Bearer $discoverToken"; "Foundry-Features" = "HostedAgents=V1Preview,AgentEndpoints=V1Preview" }
    $existing = Invoke-RestMethod -Method Get -Headers $dh -ErrorAction Stop `
        -Uri "$($env:AZURE_AI_PROJECT_ENDPOINT)/agents/$($env:AGENT_NAME)/versions/1?api-version=2025-11-15-preview"
    if ($existing.blueprint_reference.blueprint_id) {
        $env:AGENT_BLUEPRINT_NAME = $existing.blueprint_reference.blueprint_id
        Write-Host "Reusing existing blueprint: $env:AGENT_BLUEPRINT_NAME"
    }
    if ($existing.blueprint.client_id) {
        $env:BLUEPRINT_CLIENT_ID = $existing.blueprint.client_id
    }
} catch {
    Write-Host "No existing agent version found — first deploy (blueprint will be auto-created)."
}

# --- Agentic OBO (real user passthrough) config --------------------------------
# The agent mints user-delegated tokens AS the provisioned agent-user via a 3-leg
# exchange (blueprint -> ServiceIdentity instance -> user_fic). TENANT_ID comes from
# the azd env; the rest are supplied as params / env (defaults to the autopilot's
# provisioned identities so the standalone agent gets the same real mailbox + Fabric).
if ($OboBlueprintClientId) { $env:OBO_BLUEPRINT_CLIENT_ID = $OboBlueprintClientId }
if ($OboBlueprintSecret)   { $env:OBO_BLUEPRINT_SECRET    = $OboBlueprintSecret }
if ($OboInstanceClientId)  { $env:OBO_INSTANCE_CLIENT_ID  = $OboInstanceClientId }
if ($OboAgentUserId)       { $env:OBO_AGENT_USER_ID       = $OboAgentUserId }
if ($env:OBO_BLUEPRINT_CLIENT_ID -and $env:OBO_BLUEPRINT_SECRET -and $env:OBO_INSTANCE_CLIENT_ID -and $env:OBO_AGENT_USER_ID) {
    Write-Host "Agentic OBO: enabled (agent-user=$($env:OBO_AGENT_USER_ID) via ServiceIdentity=$($env:OBO_INSTANCE_CLIENT_ID))"
} else {
    Write-Host "Agentic OBO: DISABLED (need OBO_BLUEPRINT_CLIENT_ID/SECRET + OBO_INSTANCE_CLIENT_ID + OBO_AGENT_USER_ID) — Work IQ/Fabric-as-user will not work."
}

Write-Host "Deploy target (hosting) : $env:AZURE_AI_PROJECT_ENDPOINT"
Write-Host "IQ project (connections): $env:IQ_PROJECT_ENDPOINT"
Write-Host "IQ account              : $env:IQ_ACCOUNT_RESOURCE_ID"
Write-Host "Agent name              : $env:AGENT_NAME"

# --- [1/3] Build image ----------------------------------------------------------
Write-Host "`n=============== [1/3] Building image ==============="
& "$PSScriptRoot/build-image-acr.ps1"

# --- [2/3] Create the hosted agent version -------------------------------------
# Single pass: the platform auto-creates the agent-identity blueprint + instance
# identity and INJECTS the instance client id into the container itself (that env
# var is reserved), so no rebuild / identity pinning is needed.
Write-Host "`n=============== [2/3] Creating agent version ==============="
$ids = & "$PSScriptRoot/create-agent-version.ps1"
if (-not $ids.InstanceClientId) { throw "Version-create did not return an instance client id." }
Write-Host "Instance client id: $($ids.InstanceClientId)  Blueprint: $($ids.BlueprintName)"

# --- [3/3] Grants ---------------------------------------------------------------
Write-Host "`n=============== [3/3] Granting IQ + Fabric access ==============="
& "$PSScriptRoot/grant-fabric-and-iq-access.ps1" `
    -InstanceClientId $ids.InstanceClientId `
    -IqAccountResourceId $env:IQ_ACCOUNT_RESOURCE_ID `
    -FabricWorkspaceId $FabricWorkspaceId

# --- Retire older versions so the portal Playground can only load the new one ----
# The Foundry portal Playground can pin an old version in a cached session; retiring
# prior versions forces every session onto @latest (the version just deployed).
$newVer = [int]$ids.AgentVersion
if ($newVer -gt 1) {
    Write-Host "`nRetiring older versions (< $newVer) ..."
    $rt = az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv
    $rh = @{ Authorization = "Bearer $rt"; "Foundry-Features" = "HostedAgents=V1Preview,AgentEndpoints=V1Preview" }
    for ($n = 1; $n -lt $newVer; $n++) {
        try {
            Invoke-RestMethod -Method Delete -Headers $rh -ErrorAction Stop `
                -Uri "$($env:AZURE_AI_PROJECT_ENDPOINT)/agents/$($env:AGENT_NAME)/versions/$n`?api-version=2025-11-15-preview&force=true" | Out-Null
            Write-Host "  v$n retired"
        } catch { }
    }
}

Write-Host ""
Write-Host "Deploy complete." -ForegroundColor Green
Write-Host "  Agent name         : $env:AGENT_NAME"
Write-Host "  Agent version      : $($ids.AgentVersion)"
Write-Host "  Instance client id : $($ids.InstanceClientId)"
Write-Host ""
Write-Host "Open the agent in the Foundry portal (hosting project) and use the Playground." -ForegroundColor Cyan
Write-Host "It is NOT hired into Teams, so the inline Playground stays enabled."
