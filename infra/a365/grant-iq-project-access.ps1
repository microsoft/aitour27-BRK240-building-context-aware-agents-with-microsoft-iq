#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Post-hire grants that let the four IQs resolve on-behalf-of the hired agent user.

.DESCRIPTION
  Some access can only be granted AFTER an autopilot instance is hired in Teams,
  because the agent-user account and its ServiceIdentity do not exist until then.
  This script is idempotent — run it once after hiring the instance.

  It grants, on the EXISTING IQ project (where the Web/Foundry/Work/Fabric IQ
  connections live — the agent targets it via IQ_PROJECT_ENDPOINT):

    1. Cognitive Services User to the agent's **instance identity** (app path).
    2. Cognitive Services User to the hired **agent user** (OBO path) — the Foundry
       Responses call is made AS this user object when OBO succeeds.

  And, if -FabricWorkspaceId is supplied, adds the agent user as a **Member** of the
  Fabric workspace that backs the Fabric IQ data agent (required for Fabric OBO).

.PARAMETER IqAccountResourceId
  ARM resource id of the Cognitive Services/AIServices account that hosts the IQ
  connections (the account behind IQ_PROJECT_ENDPOINT). Example:
  /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<account>

.PARAMETER AgentName
  Hosted agent name (default caldova-supply-autopilot). Used to discover the agent-user
  account by display name.

.PARAMETER FabricWorkspaceId
  Optional. GUID of the Fabric workspace backing the Fabric IQ data agent
  (e.g. your Caldova Fabric workspace). If provided, the agent user is added as a Member.
#>
param(
    [Parameter(Mandatory = $true)][string]$IqAccountResourceId,
    [string]$AgentName = "caldova-supply-autopilot",
    [string]$FabricWorkspaceId
)
$ErrorActionPreference = "Stop"

$cogSvcUserRole = "a97b65f3-24c7-4388-baec-2e87135dc908"  # Cognitive Services User

# --- Resolve the instance identity client id (written to azd env by post-provision) ---
$instanceClientId = (azd env get-values | Where-Object { $_ -match '^AGENT_INSTANCE_CLIENT_ID=' }) -replace '^AGENT_INSTANCE_CLIENT_ID="?|"?$', ''
if ($instanceClientId) {
    Write-Host "Granting Cognitive Services User to instance identity $instanceClientId ..."
    $o = az role assignment create --assignee-object-id $instanceClientId --assignee-principal-type ServicePrincipal --role $cogSvcUserRole --scope $IqAccountResourceId 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -or $o -match 'RoleAssignmentExists') { Write-Host "  ok" } else { Write-Host "  WARNING: $o" }
}

# --- Discover the hired agent user (created on hire) by display name ---
$gtok = az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv
$filter = [uri]::EscapeDataString("startswith(displayName,'$AgentName')")
$users = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users?`$filter=$filter&`$select=id,displayName,userPrincipalName" -Headers @{ Authorization = "Bearer $gtok" }
$agentUser = $users.value | Select-Object -First 1
if (-not $agentUser) {
    # Autopilot agent users may not match the agent name exactly; try the friendly name.
    $filter = [uri]::EscapeDataString("startswith(displayName,'Caldova Supply Autopilot')")
    $users = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users?`$filter=$filter&`$select=id,displayName,userPrincipalName" -Headers @{ Authorization = "Bearer $gtok" }
    $agentUser = $users.value | Select-Object -First 1
}
if (-not $agentUser) { throw "Could not find the hired agent user. Hire the instance in Teams first, then re-run." }
Write-Host "Agent user: $($agentUser.displayName) ($($agentUser.userPrincipalName)) id=$($agentUser.id)"

Write-Host "Granting Cognitive Services User to agent user (OBO identity) ..."
$o = az role assignment create --assignee-object-id $agentUser.id --assignee-principal-type User --role $cogSvcUserRole --scope $IqAccountResourceId 2>&1 | Out-String
if ($LASTEXITCODE -eq 0 -or $o -match 'RoleAssignmentExists') { Write-Host "  ok" } else { Write-Host "  WARNING: $o" }

# --- Optional: add the agent user to the Fabric workspace (Fabric IQ OBO) ---
if ($FabricWorkspaceId) {
    Write-Host "Adding agent user as Member of Fabric workspace $FabricWorkspaceId ..."
    $ftok = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv
    $body = @{ principal = @{ id = $agentUser.id; type = "User" }; role = "Member" } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri "https://api.fabric.microsoft.com/v1/workspaces/$FabricWorkspaceId/roleAssignments" -Method Post -Headers @{ Authorization = "Bearer $ftok"; "Content-Type" = "application/json" } -Body $body | Out-Null
        Write-Host "  ok"
    } catch {
        $m = $_.ErrorDetails.Message
        if ($m -and ($m -like "*already*")) { Write-Host "  already a member - ignoring" } else { Write-Host "  WARNING: $m" }
    }
}

# --- Ensure the OBO delegated scopes are consented on the per-instance identities ---
# The blueprint SP grants (create-blueprintsp-oauth2-grants.ps1) are inheritable, but
# granting the instance + ServiceIdentity SPs directly is a reliable belt-and-suspenders
# so the agentic-user exchange for ai.azure.com succeeds regardless of which identity the
# runtime uses as the token requester.
$graphToken = az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv
$gh = @{ Authorization = "Bearer $graphToken"; "Content-Type" = "application/json" }
$oboResources = @(
    @{ Name = "Microsoft Graph";        AppId = "00000003-0000-0000-c000-000000000000"; Scope = "Mail.ReadWrite Mail.Send Chat.ReadWrite User.Read.All Sites.Read.All Files.ReadWrite.All ChannelMessage.Read.All ChannelMessage.Send" }
    @{ Name = "Azure Machine Learning"; AppId = "18a66f5f-dbdf-4c17-9dd7-1634712a9cbe"; Scope = "user_impersonation" }
    @{ Name = "Power Platform API";     AppId = "8578e004-a5c6-46e7-913e-12f58912df43"; Scope = "Connectivity.Connections.Read" }
)
# The container's ServiceIdentity SP shares the agent user's display name; the instance
# AgentIdentity SP is the AGENT_INSTANCE_CLIENT_ID.
$svcSp = (az ad sp show --id (az ad sp list --filter "displayName eq '$($agentUser.displayName)'" --query "[?servicePrincipalType=='ServiceIdentity'].appId | [0]" -o tsv 2>$null) --query id -o tsv 2>$null)
$clientSpIds = @()
if ($svcSp) { $clientSpIds += $svcSp }
if ($instanceClientId) { $clientSpIds += (az ad sp show --id $instanceClientId --query id -o tsv 2>$null) }
foreach ($clientSp in ($clientSpIds | Where-Object { $_ })) {
    foreach ($r in $oboResources) {
        $resSp = az ad sp show --id $r.AppId --query id -o tsv 2>$null
        $b = @{ clientId = $clientSp; consentType = "AllPrincipals"; principalId = $null; resourceId = $resSp; scope = $r.Scope } | ConvertTo-Json
        try { Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/oauth2PermissionGrants" -Method Post -Headers $gh -Body $b | Out-Null; Write-Host "  $clientSp <= $($r.Name): granted" }
        catch { $m = $_.ErrorDetails.Message; if ($m -and $m -like "*already exists*") { Write-Host "  $clientSp <= $($r.Name): exists" } else { Write-Host "  $clientSp <= $($r.Name): WARNING $m" } }
    }
}

Write-Host ""
Write-Host "Done. Allow a few minutes for RBAC/consent to propagate, then test the four IQs in Teams." -ForegroundColor Green
