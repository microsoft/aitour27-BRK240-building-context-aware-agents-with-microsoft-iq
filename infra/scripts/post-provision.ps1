#!/usr/bin/env pwsh
# =============================================================================
# post-provision (DEPLOY phase)
#
# Runs as the azd `postprovision` hook, after infra/main.bicep provisions the
# Foundry account + project + ACR. This builds the container and creates the
# hosted agent, mirroring the iqdeepdive autopilot's *deploy* step. It does NOT
# perform the Agent 365 registration — that is a separate, admin-gated step run
# afterwards via ./infra/a365/publish-autopilot.ps1.
#
# Auto-create blueprint => two passes (see scripts/agent-creation-script.ps1):
#   1. Build image with a placeholder blueprint id, create the first version.
#      The platform auto-creates the blueprint + instance identity and returns
#      their client ids.
#   2. Rebuild the image baking those real ids, create a second version. Traffic
#      routes to @latest, so it rolls forward once healthy.
# =============================================================================
$ErrorActionPreference = "Stop"
Write-Host "Starting post-provision (deploy) ..."
Write-Host "Account=$env:ACCOUNT_NAME Project=$env:PROJECT_NAME Agent=$env:AGENT_NAME Location=$env:AZURE_LOCATION"

# On re-runs, reuse the existing auto-created blueprint (by NAME) so the platform does
# not spin up a second one. First-ever deploy leaves this empty -> auto-create.
if ($env:AGENT_BLUEPRINT_NAME) {
    Write-Host "Reusing existing blueprint: $env:AGENT_BLUEPRINT_NAME"
}

# --------------------------------------------------------------------------
# [0/4] Optional: seed the four IQ data sources + register their project
# connections BEFORE the build, so the container bakes the Caldova connection
# ids. Opt-in via SEED_IQ_ON_PROVISION (seeding is slow and needs Search +
# Fabric rights). azd env set doesn't propagate to this process, so we also
# copy the returned ids into $env: here for the build/version steps below.
# --------------------------------------------------------------------------
if ($env:SEED_IQ_ON_PROVISION) {
    Write-Host "=============== [0/4] Seeding IQ data + registering connections ==============="
    $seedArgs = @{ SetAzdEnv = $true }
    if ($env:WEB_IQ_API_KEY) { $seedArgs.WebIqApiKey = $env:WEB_IQ_API_KEY }
    $conn = & "$PSScriptRoot/seed-and-connect.ps1" @seedArgs
    if ($conn.FoundryIqConnectionId) { $env:FOUNDRY_IQ_CONNECTION_ID = $conn.FoundryIqConnectionId }
    if ($conn.FoundryIqMcpUrl)       { $env:FOUNDRY_IQ_MCP_URL       = $conn.FoundryIqMcpUrl }
    if ($conn.FabricConnectionId)    { $env:FABRIC_CONNECTION_ID     = $conn.FabricConnectionId }
    if ($conn.WorkIqConnectionId)    { $env:WORK_IQ_CONNECTION_ID    = $conn.WorkIqConnectionId }
    if ($conn.WebIqConnectionId)     { $env:WEB_IQ_CONNECTION_ID     = $conn.WebIqConnectionId }
}
else {
    Write-Host "Skipping IQ seeding (set SEED_IQ_ON_PROVISION=1 to seed data + register connections)."
}

Write-Host "=============== [1/4] Building image (pass 1, placeholder blueprint) ==============="
& "$PSScriptRoot/build-docker-image-acr.ps1"

Write-Host "=============== [2/4] Creating agent version (pass 1, auto-create blueprint) ==============="
$ids = & "$PSScriptRoot/agent-creation-script.ps1"
if (-not $ids.BlueprintClientId) {
    throw "Version-create did not return a blueprint client id; cannot complete pass 2."
}
Write-Host "Blueprint clientId=$($ids.BlueprintClientId) name=$($ids.BlueprintName) instance=$($ids.InstanceClientId)"

Write-Host "=============== [3/4] Rebuilding image with real ids (pass 2) ==============="
$env:AGENT_BLUEPRINT_CLIENT_ID = $ids.BlueprintClientId
$env:AGENT_INSTANCE_CLIENT_ID  = $ids.InstanceClientId
$env:AGENT_BLUEPRINT_NAME       = $ids.BlueprintName
& "$PSScriptRoot/build-docker-image-acr.ps1"

Write-Host "=============== [4/4] Creating agent version (pass 2, real blueprint baked) ==============="
$ids2 = & "$PSScriptRoot/agent-creation-script.ps1"

# Persist ids into the azd environment for infra/a365/publish-autopilot.ps1.
# AGENT_IDENTITY_BLUEPRINT_ID is the blueprint app/client id GUID (Bot Service msaAppId,
# publish botId, `az ad sp show`). AGENT_BLUEPRINT_NAME is the blueprint NAME (reuse ref).
azd env set AGENT_IDENTITY_BLUEPRINT_ID   $ids2.BlueprintClientId    | Out-Null
azd env set AGENT_BLUEPRINT_NAME          $ids2.BlueprintName        | Out-Null
azd env set AGENT_BLUEPRINT_PRINCIPAL_ID  $ids2.BlueprintPrincipalId | Out-Null
azd env set AGENT_INSTANCE_CLIENT_ID      $ids2.InstanceClientId     | Out-Null
azd env set AGENT_GUID                    $ids2.AgentGuid            | Out-Null

Write-Host ""
Write-Host "Deploy complete." -ForegroundColor Green
Write-Host "  Blueprint client id : $($ids2.BlueprintClientId)"
Write-Host "  Blueprint name      : $($ids2.BlueprintName)"
Write-Host "  Instance client id  : $($ids2.InstanceClientId)"
Write-Host "  Agent GUID          : $($ids2.AgentGuid)"
Write-Host ""
Write-Host "Next: register the agent in Agent 365 ->" -ForegroundColor Cyan
Write-Host "  ./infra/a365/publish-autopilot.ps1"
