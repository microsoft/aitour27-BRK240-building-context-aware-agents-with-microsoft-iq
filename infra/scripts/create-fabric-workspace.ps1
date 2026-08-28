#!/usr/bin/env pwsh
# =================================================================================================
# Create a Microsoft Fabric workspace via the Fabric REST API and attach it to a capacity.
#
# A Fabric *capacity* is provisioned by Bicep (infra/modules/fabric.bicep), but a *workspace* is
# not an ARM resource — it is created through the Fabric REST API. This script fills that gap so
# `azd up` can build the demo end to end without asking the presenter to create a workspace by hand.
#
# Returns the new workspace GUID. With -SetAzdEnv, it also stores it as FABRIC_WORKSPACE_ID.
# =================================================================================================
[CmdletBinding()]
param(
    [string]$WorkspaceName = "caldova-supply",
    [string]$CapacityName  = $(if ($env:FABRIC_EXISTING_CAPACITY_NAME) { $env:FABRIC_EXISTING_CAPACITY_NAME } else { $env:FABRIC_CAPACITY_NAME }),
    [switch]$SetAzdEnv
)
$ErrorActionPreference = "Stop"
$fabricApi = "https://api.fabric.microsoft.com/v1"

function Get-FabricToken {
    $token = az account get-access-token --resource "https://api.fabric.microsoft.com" --query accessToken -o tsv 2>$null
    if (-not $token) { throw "Could not get a Microsoft Fabric access token. Run 'az login' first." }
    return $token
}

$token   = Get-FabricToken
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

# 1. Reuse a workspace with the same name if one already exists (idempotent re-runs).
$existing = (Invoke-RestMethod -Method Get -Uri "$fabricApi/workspaces" -Headers $headers).value |
    Where-Object { $_.displayName -eq $WorkspaceName } | Select-Object -First 1
if ($existing) {
    Write-Host "Reusing existing Fabric workspace '$WorkspaceName' ($($existing.id))." -ForegroundColor Yellow
    $workspaceId = $existing.id
} else {
    # 2. Resolve the capacity GUID (the Fabric API needs the capacity object id, not the ARM id).
    $capacityId = $null
    if ($CapacityName) {
        $capacityId = ((Invoke-RestMethod -Method Get -Uri "$fabricApi/capacities" -Headers $headers).value |
            Where-Object { $_.displayName -eq $CapacityName } | Select-Object -First 1).id
        if (-not $capacityId) {
            Write-Warning "Fabric capacity '$CapacityName' not found via the Fabric API; creating the workspace without a capacity."
        }
    }

    # 3. Create the workspace (attach the capacity when we have one).
    $body = @{ displayName = $WorkspaceName }
    if ($capacityId) { $body.capacityId = $capacityId }
    $created = Invoke-RestMethod -Method Post -Uri "$fabricApi/workspaces" -Headers $headers -Body ($body | ConvertTo-Json)
    $workspaceId = $created.id
    Write-Host "Created Fabric workspace '$WorkspaceName' ($workspaceId)$(if ($capacityId) { " on capacity $CapacityName" })." -ForegroundColor Green
}

if ($SetAzdEnv) { azd env set FABRIC_WORKSPACE_ID $workspaceId | Out-Null }
return $workspaceId
