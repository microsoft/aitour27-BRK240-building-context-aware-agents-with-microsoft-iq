#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Provision the Caldova "one toolbox, four Microsoft IQs" setup used by the Foundry
  Hosted Agent — a Foundry toolbox (``caldova-supply-tools``) that Microsoft Foundry runs
  with **auth passthrough**, so Fabric IQ and Work IQ resolve as the **signed-in user**.

.DESCRIPTION
  Creates (idempotently):
    1. ``fabric-iq-caldova`` — a RemoteTool / UserEntraToken / custom_MCP connection that
       targets the Caldova Fabric Data Agent MCP endpoint (per-user identity).
    2. ``caldova-supply-tools`` — a toolbox version bundling all four Microsoft IQ tools
       (Fabric IQ ``fabric_iq_preview`` + Work IQ + Foundry IQ + Web IQ), promoted as the
       default version.

  The Fabric Data Agent and the WorkIQ / caldova-supply-kb / WebIQ connections must
  already exist in the project (created by the seeding step).

.NOTES
  Requires: az logged in with access to the Foundry project + the AI Services account.
#>
param(
    [Parameter(Mandatory = $true)][string]$ProjectEndpoint,          # https://<acct>.services.ai.azure.com/api/projects/<proj>
    [Parameter(Mandatory = $true)][string]$AccountResourceId,        # /subscriptions/.../accounts/<acct>
    [Parameter(Mandatory = $true)][string]$FabricWorkspaceId,        # GUID of the Fabric workspace
    [Parameter(Mandatory = $true)][string]$FabricDataAgentId,        # GUID of the Fabric Data Agent
    [string]$ToolboxName          = "caldova-supply-tools",
    [string]$FabricConnectionName = "fabric-iq-caldova",
    [string]$WorkIqConnection     = "WorkIQ",
    [string]$FoundryIqConnection  = "caldova-supply-kb",
    [string]$WebIqConnection      = "WebIQ"
)
$ErrorActionPreference = "Stop"

$fabricMcpUrl = "https://api.fabric.microsoft.com/v1/mcp/workspaces/$FabricWorkspaceId/dataagents/$FabricDataAgentId/agent"

# 1) Fabric IQ per-user MCP connection (UserEntraToken → resolves as the signed-in user).
Write-Host "Creating connection '$FabricConnectionName' -> $fabricMcpUrl"
$connBody = @{
    properties = @{
        authType    = "UserEntraToken"
        category    = "RemoteTool"
        group       = "GenericProtocol"
        audience    = "https://analysis.windows.net/powerbi/api"
        target      = $fabricMcpUrl
        isSharedToAll = $true
        metadata    = @{ type = "custom_MCP" }
        useWorkspaceManagedIdentity = $false
    }
} | ConvertTo-Json -Depth 6
$tmp = New-TemporaryFile
$connBody | Out-File $tmp -Encoding utf8
az rest --method put `
    --url "https://management.azure.com$AccountResourceId/connections/$FabricConnectionName`?api-version=2025-06-01" `
    --body "@$tmp" | Out-Null
Remove-Item $tmp -ErrorAction SilentlyContinue
Write-Host "  connection ready."

# 2) Toolbox with all four Microsoft IQ tools.
$token = az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
$tools = @(
    @{ type = "fabric_iq_preview"; name = "supplier_analytics"; project_connection_id = $FabricConnectionName; server_label = $FabricConnectionName; server_url = $fabricMcpUrl; require_approval = "never" },
    @{ type = "mcp"; server_label = "workiq";    project_connection_id = $WorkIqConnection;    require_approval = "never" },
    @{ type = "mcp"; server_label = "foundryiq"; project_connection_id = $FoundryIqConnection; require_approval = "never" },
    @{ type = "mcp"; server_label = "webiq";     project_connection_id = $WebIqConnection;     require_approval = "never" }
)
$tbBody = @{
    description = "Caldova supply toolbox — Fabric IQ + Work IQ preserve the signed-in user; Foundry IQ + Web IQ over the same call."
    tools       = $tools
} | ConvertTo-Json -Depth 8

Write-Host "Creating toolbox '$ToolboxName' version ..."
$version = Invoke-RestMethod -Method Post -Headers $headers `
    -Uri "$($ProjectEndpoint.TrimEnd('/'))/toolboxes/$ToolboxName/versions?api-version=v1" -Body $tbBody
Invoke-RestMethod -Method Patch -Headers $headers `
    -Uri "$($ProjectEndpoint.TrimEnd('/'))/toolboxes/$ToolboxName`?api-version=v1" `
    -Body (@{ default_version = "$($version.version)" } | ConvertTo-Json) | Out-Null
Write-Host "Toolbox '$ToolboxName' default version set to $($version.version)."
Write-Host ""
Write-Host "Done. The Foundry Hosted Agent points at:"
Write-Host "  $($ProjectEndpoint.TrimEnd('/'))/toolboxes/$ToolboxName/mcp?api-version=v1"
