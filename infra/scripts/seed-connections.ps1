#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Register the Foundry project connections the Caldova Supply Autopilot needs.

.DESCRIPTION
  After seeding (seed.ps1 / seed-and-connect.ps1), the four IQs are reached through
  **Foundry project connections**. This script creates/updates them on the target
  Foundry project via the ARM control plane.

  Validated live:
    - Foundry IQ knowledge-base connection (ProjectManagedIdentity -> Search KB MCP).
    - Fabric IQ Data Agent connection (CustomKeys: workspace-id + artifact-id).
    - Web IQ / Work IQ connections mirror the standard shapes below.

  Fabric IQ note: a Fabric Data Agent connection (`fabric_dataagent_preview`) binds to a
  SPECIFIC published Data Agent through two CustomKeys: `workspace-id` (the Fabric
  workspace GUID, prefixed with `/`) and `artifact-id` (the published Data Agent GUID).
  Pass -FabricWorkspaceId and -FabricDataAgentId (the SupplierDataAgent GUID, discovered
  by seed-and-connect.ps1) to create it.

.PARAMETER SubscriptionId / ResourceGroup / AccountName / ProjectName
  The Foundry (Cognitive Services) account + project that hosts the IQ connections.

.PARAMETER SearchEndpoint / KbName
  The Azure AI Search service endpoint and the seeded knowledge base name.
#>
param(
    [Parameter(Mandatory = $true)][string]$SubscriptionId,
    [Parameter(Mandatory = $true)][string]$ResourceGroup,
    [Parameter(Mandatory = $true)][string]$AccountName,
    [Parameter(Mandatory = $true)][string]$ProjectName,
    [Parameter(Mandatory = $true)][string]$SearchEndpoint,
    [string]$KbName = "caldova-supply-kb",
    [string]$KbApiVersion = "2026-05-01-preview",
    # Fabric Data Agent binding (SupplierDataAgent, discovered by seed-and-connect.ps1).
    # When both are set, the Fabric IQ connection is created automatically.
    [string]$FabricWorkspaceId,
    [string]$FabricDataAgentId,
    [string]$FabricConnectionName = "caldova-supply-dataagent",
    # Web IQ subscription key (the 'x-apikey' header value for api.microsoft.ai).
    # Provide your own key to auto-create the Web IQ connection.
    [string]$WebIqApiKey,
    # Persist the resulting connection ids into the current azd environment so the
    # deploy step (agent-creation-script.ps1) wires them into the container.
    [switch]$SetAzdEnv
)
$ErrorActionPreference = "Stop"

$token = az account get-access-token --resource https://management.azure.com --query accessToken -o tsv
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
$armBase = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.CognitiveServices/accounts/$AccountName/projects/$ProjectName/connections"
$base = "https://management.azure.com$armBase"

# Returns the ARM resource id of the connection on success, else $null.
function New-Connection([string]$name, [hashtable]$properties) {
    $body = @{ properties = $properties } | ConvertTo-Json -Depth 8
    $r = Invoke-WebRequest -Uri "$base/$name`?api-version=2025-06-01" -Method Put -Headers $headers -Body $body -SkipHttpErrorCheck
    if ([int]$r.StatusCode -ge 400) { Write-Host "  $name -> FAILED $($r.StatusCode): $($r.Content)"; return $null }
    Write-Host "  $name -> $($r.StatusCode)"
    return "$armBase/$name"
}

$ids = [ordered]@{}

Write-Host "=== Foundry IQ (knowledge base) connection ===" -ForegroundColor Cyan
$kbMcp = "$($SearchEndpoint.TrimEnd('/'))/knowledgebases/$KbName/mcp?api-version=$KbApiVersion"
$ids.FoundryIqConnectionId = New-Connection $KbName @{
    authType = "ProjectManagedIdentity"
    audience = "https://search.azure.com"
    group    = "GenericProtocol"
    category = "RemoteTool"
    target   = $kbMcp
    metadata = @{ type = "knowledgeBase_MCP"; knowledgeBaseName = $KbName }
}
$ids.FoundryIqMcpUrl = $kbMcp

Write-Host "=== Web IQ connection ===" -ForegroundColor Cyan
if ($WebIqApiKey) {
    $ids.WebIqConnectionId = New-Connection "WebIQ" @{
        authType    = "CustomKeys"; group = "GenericProtocol"; category = "RemoteTool"
        target      = "https://api.microsoft.ai/v3/mcp"; metadata = @{ type = "custom_MCP" }
        credentials = @{ keys = @{ "x-apikey" = $WebIqApiKey } }
    }
}
else {
    Write-Host "  Skipped (pass -WebIqApiKey with your api.microsoft.ai subscription key)." -ForegroundColor Yellow
}

Write-Host "=== Work IQ connection ===" -ForegroundColor Cyan
$ids.WorkIqConnectionId = New-Connection "WorkIQ" @{
    authType = "UserEntraToken"; audience = "fdcc1f02-fc51-4226-8753-f668596af7f7"
    group = "GenericProtocol"; category = "RemoteTool"
    target = "https://workiq.svc.cloud.microsoft/mcp"; metadata = @{ type = "custom_MCP" }
}

Write-Host "=== Fabric IQ (Data Agent) connection ===" -ForegroundColor Cyan
if ($FabricWorkspaceId -and $FabricDataAgentId) {
    $ids.FabricConnectionId = New-Connection $FabricConnectionName @{
        authType    = "CustomKeys"
        group       = "AzureAI"
        category    = "CustomKeys"
        target      = "-"
        credentials = @{ keys = @{ "workspace-id" = "/$FabricWorkspaceId"; "artifact-id" = $FabricDataAgentId } }
        metadata    = @{ type = "fabric_dataagent_preview" }
    }
}
else {
    Write-Host "  Skipped (pass -FabricWorkspaceId and -FabricDataAgentId; the SupplierDataAgent GUID is discovered by seed-and-connect.ps1)." -ForegroundColor Yellow
}

if ($SetAzdEnv) {
    Write-Host "=== Persisting connection ids into the azd environment ===" -ForegroundColor Cyan
    $map = [ordered]@{
        FOUNDRY_IQ_CONNECTION_ID = $ids.FoundryIqConnectionId
        FOUNDRY_IQ_MCP_URL       = $ids.FoundryIqMcpUrl
        FABRIC_CONNECTION_ID     = $ids.FabricConnectionId
        WORK_IQ_CONNECTION_ID    = $ids.WorkIqConnectionId
        WEB_IQ_CONNECTION_ID     = $ids.WebIqConnectionId
    }
    foreach ($k in $map.Keys) {
        if ($map[$k]) { azd env set $k $map[$k] | Out-Null; Write-Host "  azd env set $k" }
    }
}

Write-Host ""
Write-Host "Connections registered." -ForegroundColor Green
return $ids
