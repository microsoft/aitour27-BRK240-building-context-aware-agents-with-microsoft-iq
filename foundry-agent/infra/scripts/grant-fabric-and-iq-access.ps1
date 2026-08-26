#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Grant the standalone agent's instance identity everything it needs for the three
  IQs to resolve under its own **app identity** (no signed-in user).

.DESCRIPTION
  The standalone agent runs its Responses call as its instance identity (a
  ServicePrincipal). For the three IQs to resolve server-side:

    * Web IQ + Foundry IQ  -> resolve from their project connections once the
      identity has **Cognitive Services User** on the IQ project account.
    * Fabric IQ            -> additionally requires the identity to be a **Member
      of the Fabric workspace** behind the Fabric Data Agent. This is the piece
      that lets Fabric work WITHOUT a signed-in user (the autopilot relied on the
      hired user's OBO membership instead).

  Idempotent — safe to re-run.

  NOTE: adding a ServicePrincipal to a Fabric workspace requires the tenant setting
  "Service principals can use Fabric APIs" to be enabled for that SP (or a group it
  belongs to). If Fabric access still fails after this grant, that tenant toggle is
  the most likely cause.

.PARAMETER InstanceClientId
  The instance identity client id returned by create-agent-version.ps1.

.PARAMETER IqAccountResourceId
  ARM id of the AIServices account that hosts the IQ connections (behind
  IQ_PROJECT_ENDPOINT).

.PARAMETER FabricWorkspaceId
  GUID of the Fabric workspace backing the Fabric Data Agent. Optional — omit to
  skip the Fabric membership grant (Web + Foundry IQ will still work).
#>
param(
    [Parameter(Mandatory = $true)][string]$InstanceClientId,
    [Parameter(Mandatory = $true)][string]$IqAccountResourceId,
    [string]$FabricWorkspaceId
)
$ErrorActionPreference = "Stop"

$cogSvcUser = "a97b65f3-24c7-4388-baec-2e87135dc908"  # Cognitive Services User

$instanceObjectId = az ad sp show --id $InstanceClientId --query id -o tsv 2>$null
if (-not $instanceObjectId) { throw "Could not resolve object id for instance client id $InstanceClientId" }

Write-Host "Granting Cognitive Services User to instance identity on the IQ account ..."
$o = az role assignment create --assignee-object-id $instanceObjectId --assignee-principal-type ServicePrincipal `
    --role $cogSvcUser --scope $IqAccountResourceId 2>&1 | Out-String
if ($LASTEXITCODE -eq 0 -or $o -match 'RoleAssignmentExists') { Write-Host "  ok" } else { Write-Host "  WARNING: $o" }

if ($FabricWorkspaceId) {
    Write-Host "Adding instance identity as Member of Fabric workspace $FabricWorkspaceId ..."
    $ftok = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv
    $fbody = @{ principal = @{ id = $instanceObjectId; type = "ServicePrincipal" }; role = "Member" } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri "https://api.fabric.microsoft.com/v1/workspaces/$FabricWorkspaceId/roleAssignments" `
            -Method Post -Headers @{ Authorization = "Bearer $ftok"; "Content-Type" = "application/json" } -Body $fbody | Out-Null
        Write-Host "  ok"
    } catch {
        $m = $_.ErrorDetails.Message
        if ($m -and $m -like "*already*") { Write-Host "  already a member - ignoring" } else { Write-Host "  WARNING: $m" }
    }
} else {
    Write-Host "FabricWorkspaceId not supplied — skipping Fabric membership grant (Fabric IQ will not resolve until it is added)."
}

# --- Work IQ / Graph delegated consent (parity with the autopilot) --------------
# Work IQ acts on-behalf-of a signed-in user. It is not exercised under pure app
# identity, but we consent the same delegated scopes on the instance SP so that if
# a user token IS forwarded (portal), the Work IQ path can succeed. Idempotent.
Write-Host "Consenting Work IQ + Graph delegated scopes on the instance identity ..."
$graphToken = az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv
$gh = @{ Authorization = "Bearer $graphToken"; "Content-Type" = "application/json" }
$oboResources = @(
    @{ Name = "Microsoft Graph"; AppId = "00000003-0000-0000-c000-000000000000"; Scope = "Mail.ReadWrite Mail.Send Chat.ReadWrite User.Read.All Sites.Read.All Files.ReadWrite.All ChannelMessage.Read.All ChannelMessage.Send" }
    @{ Name = "Work IQ";         AppId = "fdcc1f02-fc51-4226-8753-f668596af7f7"; Scope = "WorkIQAgent.Ask" }
)
foreach ($r in $oboResources) {
    $resSp = az ad sp show --id $r.AppId --query id -o tsv 2>$null
    if (-not $resSp) { Write-Host "  $($r.Name): resource SP not found, skipping"; continue }
    $b = @{ clientId = $instanceObjectId; consentType = "AllPrincipals"; principalId = $null; resourceId = $resSp; scope = $r.Scope } | ConvertTo-Json
    try { Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/oauth2PermissionGrants" -Method Post -Headers $gh -Body $b | Out-Null; Write-Host "  $($r.Name): granted" }
    catch { $m = $_.ErrorDetails.Message; if ($m -and $m -like "*already exists*") { Write-Host "  $($r.Name): exists" } else { Write-Host "  $($r.Name): WARNING $m" } }
}

Write-Host ""
Write-Host "Done. Allow a few minutes for RBAC to propagate, then test the three IQs in the Foundry portal Playground." -ForegroundColor Green
