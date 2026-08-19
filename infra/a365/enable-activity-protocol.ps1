#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Ensure the hosted caldova-supply-autopilot endpoint exposes the Teams `activity`
  protocol + `BotServiceRbac` authorization.

.DESCRIPTION
  The deploy step (scripts/agent-creation-script.ps1) already requests both the
  `responses` and `activity` protocols with `Entra` + `BotServiceRbac` auth. This
  script re-asserts that in place (no new version), so the Azure Bot Service can
  call the agent's activityProtocol endpoint. Without `activity`, Teams messages
  reach the Bot but the agent never replies. Mirrors the iqdeepdive autopilot
  enable-activity-protocol.ps1.
#>
param(
    [string]$AgentName = "caldova-supply-autopilot",
    [string]$ProjectEndpoint
)
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrEmpty($ProjectEndpoint)) {
    $ProjectEndpoint = (azd env get-values | Where-Object { $_ -match '^AZURE_AI_PROJECT_ENDPOINT=' }) -replace '^AZURE_AI_PROJECT_ENDPOINT="?|"?$', ''
}
if ([string]::IsNullOrEmpty($ProjectEndpoint)) { throw "Could not resolve the project endpoint (AZURE_AI_PROJECT_ENDPOINT)." }

$token = az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv
if ([string]::IsNullOrEmpty($token)) { throw "Failed to acquire an https://ai.azure.com token." }

$headers = @{
    "Content-Type"     = "application/json"
    "Accept"           = "application/json"
    "Authorization"    = "Bearer $token"
    "Foundry-Features" = "HostedAgents=V1Preview,AgentEndpoints=V1Preview"
}

$patchUrl = "$ProjectEndpoint/agents/$AgentName`?api-version=2025-11-15-preview"
$body = @{
    agent_endpoint = @{
        protocols             = @("responses", "activity")
        authorization_schemes = @(@{ type = "Entra" }, @{ type = "BotServiceRbac" })
    }
} | ConvertTo-Json -Depth 6

Write-Host "PATCH $patchUrl"
$response = Invoke-RestMethod -Uri $patchUrl -Method Patch -Headers $headers -Body $body
$protocols = $response.agent_endpoint.protocols -join ", "
Write-Host "Agent endpoint protocols now: $protocols"
