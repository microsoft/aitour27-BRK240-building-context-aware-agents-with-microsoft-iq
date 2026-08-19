#!/usr/bin/env pwsh
<#
.SYNOPSIS
  One-shot: seed all Caldova IQ data (Fabric IQ + ontology + Foundry IQ) AND register
  the four IQ Foundry project connections, so `azd up` can bake them into the agent.

.DESCRIPTION
  Chains the reproducible building blocks so a first-time user never copies GUIDs:

    1. seed.ps1              -> Fabric IQ (SupplierDataAgent), ontology, Foundry IQ KB.
    2. discover SupplierDataAgent GUID by name in the Fabric workspace.
    3. seed-connections.ps1  -> registers the 4 IQ project connections (Foundry IQ KB,
                                Fabric IQ Data Agent, Work IQ, Web IQ) and, with
                                -SetAzdEnv, writes FOUNDRY_IQ_CONNECTION_ID /
                                FABRIC_CONNECTION_ID / ... into the azd environment.

  Reads its inputs from the current azd environment. After `azd provision`, just run this.

  Prereqs:
    - `az login` with rights on the Search service + Fabric workspace/capacity.
    - `uv` for the Fabric provision scripts; pip install -r infra/scripts/seed-requirements.txt
    - azd env has: SUBSCRIPTION_ID, RESOURCE_GROUP, ACCOUNT_NAME, PROJECT_NAME, TENANT_ID,
      AZURE_AI_SEARCH_SERVICE_ENDPOINT, FABRIC_WORKSPACE_ID.

.PARAMETER SetAzdEnv
  Persist the resulting connection ids into the azd environment (default from the azd
  hook). Also returns the id hashtable for in-process callers.

.PARAMETER WebIqApiKey
  Optional api.microsoft.ai subscription key; when set, the Web IQ connection is created
  too (otherwise skipped — Web IQ needs the operator's own key).
#>
param(
    [switch]$SetAzdEnv,
    [switch]$SkipFabric,
    [switch]$SkipOntology,
    [switch]$SkipFoundryIQ,
    [string]$FabricDataAgentName = "SupplierDataAgent",
    [string]$WebIqApiKey
)
$ErrorActionPreference = "Stop"

function Get-EnvOrThrow([string]$name) {
    $v = [Environment]::GetEnvironmentVariable($name)
    if (-not $v) { throw "Required environment value '$name' is not set (run ``azd env get-values`` or export it)." }
    return $v
}

$SubscriptionId = Get-EnvOrThrow "SUBSCRIPTION_ID"
$ResourceGroup  = Get-EnvOrThrow "RESOURCE_GROUP"
$AccountName    = Get-EnvOrThrow "ACCOUNT_NAME"
$ProjectName    = Get-EnvOrThrow "PROJECT_NAME"
$SearchEndpoint = Get-EnvOrThrow "AZURE_AI_SEARCH_SERVICE_ENDPOINT"
$FabricWorkspaceId = Get-EnvOrThrow "FABRIC_WORKSPACE_ID"

# [1] Seed the IQ data (Fabric + ontology + Foundry IQ).
& "$PSScriptRoot/seed.ps1" -SkipFabric:$SkipFabric -SkipOntology:$SkipOntology -SkipFoundryIQ:$SkipFoundryIQ

# [2] Discover the SupplierDataAgent GUID by name in the Fabric workspace.
Write-Host "=== Discovering Fabric Data Agent '$FabricDataAgentName' ===" -ForegroundColor Cyan
$fabTok = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv
$items = (Invoke-RestMethod "https://api.fabric.microsoft.com/v1/workspaces/$FabricWorkspaceId/items" `
    -Headers @{ Authorization = "Bearer $fabTok" }).value
$dataAgent = $items | Where-Object { $_.type -eq 'DataAgent' -and $_.displayName -eq $FabricDataAgentName } | Select-Object -First 1
if ($dataAgent) {
    $fabricDataAgentId = $dataAgent.id
    Write-Host "  Found: $FabricDataAgentName ($fabricDataAgentId)"
}
else {
    $fabricDataAgentId = $null
    Write-Host "  Not found; the Fabric IQ connection will be skipped." -ForegroundColor Yellow
}

# [3] Register the four IQ Foundry project connections.
Write-Host "=== Registering the four IQ Foundry project connections ===" -ForegroundColor Cyan
$ids = & "$PSScriptRoot/seed-connections.ps1" `
    -SubscriptionId $SubscriptionId `
    -ResourceGroup $ResourceGroup `
    -AccountName $AccountName `
    -ProjectName $ProjectName `
    -SearchEndpoint $SearchEndpoint `
    -FabricWorkspaceId $FabricWorkspaceId `
    -FabricDataAgentId $fabricDataAgentId `
    -WebIqApiKey $WebIqApiKey `
    -SetAzdEnv:$SetAzdEnv

Write-Host ""
Write-Host "Seed + connect complete." -ForegroundColor Green
return $ids
