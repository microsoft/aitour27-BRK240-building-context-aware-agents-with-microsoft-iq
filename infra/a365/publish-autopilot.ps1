#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Register the already-deployed hosted `caldova-supply-autopilot` as an Agent 365
  autopilot (digital worker) wired to all four IQs.

.DESCRIPTION
  scripts/post-provision.ps1 (the azd deploy step) builds the container and creates
  the hosted agent, and the platform auto-creates its blueprint + instance identity.
  This orchestrator performs the Agent 365 registration on top of that existing
  agent, mirroring the iqdeepdive autopilot's infra/a365 flow:

    0. Re-assert the `activity` protocol + BotServiceRbac auth on the endpoint.
    1. Register the Microsoft.BotService resource provider (idempotent).
    2. Deploy an Azure Bot Service (msaAppId = auto-created blueprint id, endpoint =
       the agent's activityProtocol endpoint) + Teams channel (botservice.bicep).
    3. Submit the Microsoft 365 publish (autopilot) request -> pending blueprint in
       the M365 admin center.
    4. Grant the blueprint SP the OAuth2 permissions its inheritable MCP scopes need.
    5. Add the current user as an owner of the blueprint application.

  Reads live values from `azd env get-values` (populated by post-provision.ps1:
  AGENT_IDENTITY_BLUEPRINT_ID, AGENT_INSTANCE_CLIENT_ID, AGENT_GUID) and derives the
  account/project from AZURE_AI_PROJECT_ENDPOINT.

.NOTES
  Prereqs: Owner/Contributor on the resource group (Bot Service), az + azd logged in,
  and an Agent 365 / Copilot license in the tenant.
#>
param(
    [string]$AgentName = "caldova-supply-autopilot",
    [switch]$SkipBotService,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path "$PSScriptRoot/../.."
Push-Location $repoRoot
try {
    Write-Host "=== Reading azd environment values ===" -ForegroundColor Cyan
    $envLines = azd env get-values
    $envMap = @{}
    foreach ($line in $envLines) {
        if ($line -match '^\s*([A-Z0-9_]+)="?(.*?)"?\s*$') { $envMap[$Matches[1]] = $Matches[2] }
    }

    $subscriptionId  = $envMap["AZURE_SUBSCRIPTION_ID"]
    $resourceGroup   = $envMap["AZURE_RESOURCE_GROUP"]
    $location        = $envMap["AZURE_LOCATION"]
    $projectEndpoint = $envMap["AZURE_AI_PROJECT_ENDPOINT"]
    $blueprintId     = $envMap["AGENT_IDENTITY_BLUEPRINT_ID"]
    $agentGuid       = $envMap["AGENT_GUID"]

    # Derive account + project from the project endpoint:
    # https://<account>.services.ai.azure.com/api/projects/<project>
    if ($projectEndpoint -notmatch 'https://([^.]+)\.services\.ai\.azure\.com/api/projects/([^/]+)') {
        throw "Could not parse account/project from AZURE_AI_PROJECT_ENDPOINT: $projectEndpoint"
    }
    $accountName = $Matches[1]
    $projectName = $Matches[2]

    if (-not $blueprintId) { throw "AGENT_IDENTITY_BLUEPRINT_ID not found in azd env. Run scripts/post-provision.ps1 (deploy) first." }
    if (-not $agentGuid)   { throw "AGENT_GUID not found in azd env. Run scripts/post-provision.ps1 (deploy) first." }

    # Export the env vars the sub-scripts expect.
    $env:AGENT_IDENTITY_BLUEPRINT_ID = $blueprintId
    $env:SUBSCRIPTION_ID             = $subscriptionId
    $env:AZURE_RESOURCE_GROUP        = $resourceGroup
    $env:LOCATION                    = $location
    $env:ACCOUNT_NAME                = $accountName
    $env:PROJECT_NAME                = $projectName
    $env:AGENT_NAME                  = $AgentName

    Write-Host ""
    Write-Host "Subscription : $subscriptionId"
    Write-Host "ResourceGroup: $resourceGroup"
    Write-Host "Location     : $location"
    Write-Host "Account      : $accountName"
    Write-Host "Project      : $projectName"
    Write-Host "Agent        : $AgentName (guid $agentGuid)"
    Write-Host "Blueprint    : $blueprintId"
    Write-Host ""

    if ($WhatIf) { Write-Host "-WhatIf: resolved values only, no changes made." -ForegroundColor Yellow; return }

    # 0) Ensure activity protocol + BotServiceRbac on the endpoint.
    Write-Host "=== [0/5] Enabling activity protocol on agent endpoint ===" -ForegroundColor Cyan
    & "$PSScriptRoot/enable-activity-protocol.ps1" -AgentName $AgentName -ProjectEndpoint $projectEndpoint

    # 1) Register Microsoft.BotService provider (idempotent).
    Write-Host "=== [1/5] Registering Microsoft.BotService provider ===" -ForegroundColor Cyan
    $state = az provider show --namespace Microsoft.BotService --query registrationState -o tsv 2>$null
    if ($state -ne "Registered") {
        az provider register --namespace Microsoft.BotService | Out-Null
        Write-Host "Registration requested (was: $state). This can take a few minutes."
    } else { Write-Host "Already registered." }

    # 2) Deploy the Azure Bot Service (msaAppId = auto-created blueprint id).
    if (-not $SkipBotService) {
        Write-Host "=== [2/5] Deploying Azure Bot Service ===" -ForegroundColor Cyan
        $botName = "$AgentName-bot"
        $endpoint = "https://$accountName.services.ai.azure.com/api/projects/$projectName/agents/$AgentName/endpoint/protocols/activityProtocol?api-version=2025-05-15-preview"
        az deployment group create `
            --resource-group $resourceGroup `
            --name "a365-botservice-$AgentName" `
            --template-file "$PSScriptRoot/botservice.bicep" `
            --parameters botName=$botName displayName="Caldova Supply Autopilot" msaAppId=$blueprintId endpoint=$endpoint `
            --only-show-errors | Out-Null
        Write-Host "Bot Service '$botName' deployed."
    } else { Write-Host "=== [2/5] Skipping Azure Bot Service (-SkipBotService) ===" -ForegroundColor Yellow }

    # 3) Submit the Microsoft 365 publish (autopilot) request.
    Write-Host "=== [3/5] Submitting Microsoft 365 publish (autopilot) request ===" -ForegroundColor Cyan
    & "$PSScriptRoot/publish-digital-worker.ps1" -AgentGuid $agentGuid

    # 4) OAuth2 grants for the blueprint SP.
    Write-Host "=== [4/5] Granting OAuth2 permissions to blueprint SP ===" -ForegroundColor Cyan
    & "$PSScriptRoot/create-blueprintsp-oauth2-grants.ps1"

    # 5) Add current user as blueprint owner.
    Write-Host "=== [5/5] Adding current user as blueprint owner ===" -ForegroundColor Cyan
    & "$PSScriptRoot/add-current-user-as-blueprint-owner.ps1"

    Write-Host ""
    Write-Host "Done. Next steps:" -ForegroundColor Green
    Write-Host "  1. Admin approves the pending blueprint at https://admin.cloud.microsoft/?#/agents/all/requested"
    Write-Host "  2. Set Bot ID = $blueprintId in the Teams Developer Portal (Configuration), or run ./infra/a365/configure-blueprint-backend.ps1"
    Write-Host "  3. In Teams: Apps -> Agents for your team -> find '$AgentName' -> create an instance"
    Write-Host "  4. Test the 4 IQs: order/shipment (Fabric IQ), supply policy (Foundry IQ), mailbox (Work IQ), real-time web (Web IQ)"
}
finally {
    Pop-Location
}
