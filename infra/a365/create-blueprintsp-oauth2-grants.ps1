$ErrorActionPreference = "Stop"

$blueprintSP = az ad sp show --id $env:AGENT_IDENTITY_BLUEPRINT_ID --query id -o tsv

if ([string]::IsNullOrEmpty($blueprintSP)) {
    throw "Failed to get service principal for blueprint ID $($env:AGENT_IDENTITY_BLUEPRINT_ID)"
}

Write-Host "Creating OAuth2 permission grants for blueprint service principal..."


$apxAppId = "5a807f24-c9de-44ee-a3a7-329e88a00ffc"

$apxSP = az ad sp show --id $apxAppId --query id -o tsv
if ([string]::IsNullOrEmpty($apxSP)) {
    throw "Failed to get service principal for APEX app ID $apxAppId"
}

$prodMCPAppId = "ea9ffc3e-8a23-4a7d-836d-234d7c7565c1"
$prodMCP_SP = az ad sp show --id $prodMCPAppId --query id -o tsv

if ([string]::IsNullOrEmpty($prodMCP_SP)) {
    throw "Failed to get service principal for Prod MCP app ID $prodMCPAppId"
}

# 00000003-0000-0000-c000-000000000000 is graph appId
$graphToken = az account get-access-token --resource https://graph.microsoft.com/ --query accessToken -o tsv


$mcpOauthGrant = @"
{
  "clientId": "$blueprintSP",
  "consentType": "AllPrincipals",
  "principalId": null,
  "resourceId": "$prodMCP_SP",
  "scope": "McpServers.M365Admin.All McpServers.DASearch.All McpServers.WebSearch.All McpServers.Files.All AgentTools.MOSEvents.All McpServers.Admin365Graph.All McpServers.ERPAnalytics.All McpServers.DataverseCustom.All McpServers.Dataverse.All McpServers.D365Service.All McpServers.D365Sales.All McpServers.Management.All McpServersMetadata.Read.All McpServers.Developer.All McpServers.CopilotMCP.All McpServers.OneDriveSharepoint.All McpServers.Mail.All McpServers.Teams.All McpServers.Me.All McpServers.Calendar.All McpServers.SharepointLists.All McpServers.Knowledge.All McpServers.Excel.All McpServers.Word.All McpServers.PowerPoint.All"
}
"@
# Catch "Permission entry already exists" error and continue
try {
    $response = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/oauth2PermissionGrants" `
        -Method Post `
        -Headers @{
            "Content-Type" = "application/json"
            "Accept"       = "application/json"
            "Authorization" = "Bearer $($graphToken)"
        } `
        -Body $mcpOauthGrant

    Write-Host ""
    Write-Host "MCP oauth grant response:"
    $response | ConvertTo-Json -Depth 5 | Write-Host

} catch {
    $err = $_.ErrorDetails.Message | ConvertFrom-Json
    if ($err.error.code -eq "Request_BadRequest" -and
        $err.error.message -like "*Permission entry already exists*") {

        Write-Host "Permission already exists  ignoring."
    }
    else {
        throw
    }
}


try {
    $apxOauthGrant = @"
    {
        "clientId": "$blueprintSP",
        "consentType": "AllPrincipals",
        "principalId": null,
        "resourceId": "$apxSP",
        "scope": "AgentData.ReadWrite"
    }
"@

    $response = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/oauth2PermissionGrants" `
        -Method Post `
        -Headers @{
            "Content-Type" = "application/json"
            "Accept"       = "application/json"
            "Authorization" = "Bearer $($graphToken)"
        } `
        -Body $apxOauthGrant

    Write-Host ""
    Write-Host "APX oauth grant response:"
    $response | ConvertTo-Json -Depth 5 | Write-Host
}
catch {
    $err = $_.ErrorDetails.Message | ConvertFrom-Json
    if ($err.error.code -eq "Request_BadRequest" -and
        $err.error.message -like "*Permission entry already exists*") {

        Write-Host "Permission already exists  ignoring."
    }
    else {
        throw
    }
}



# -----------------------------------------------------------------------------
# Four-IQ OBO grants — REQUIRED so the agent's agentic-USER token can be exchanged
# for https://ai.azure.com and used to resolve user-delegated IQ connections
# (Work IQ UserEntraToken, Fabric IQ) as the signed-in user. These mirror the
# delegated consent held by a known-working Foundry autopilot blueprint. Without
# them the exchange fails (AADSTS65001) and only Web IQ + Foundry IQ resolve.
#
#   - Microsoft Graph        : mail/chat/files/sites/channel scopes (Work IQ)
#   - Azure Machine Learning : user_impersonation (enables the ai.azure.com token)
#   - Power Platform API     : Connectivity.Connections.Read (Fabric / connections)
#   - Power BI Service       : DataAgent + SemanticModel + Workspace scopes (Fabric IQ —
#                              REQUIRED for the Fabric Data Agent to execute queries;
#                              without it Fabric IQ fails with PowerBIUserAccessTokenNotFoundError)
#   - Work IQ                : WorkIQAgent.Ask (REQUIRED — the agent mints a WorkIQAgent.Ask
#                              token and attaches it as the Work IQ tool header; without it
#                              the mailbox tools never resolve)
#   - Agent365Observability  : Agent365.Observability.OtelWrite (telemetry; benign)
# -----------------------------------------------------------------------------
$oboResources = @(
    @{ Name = "Microsoft Graph";        AppId = "00000003-0000-0000-c000-000000000000"; Scope = "Mail.ReadWrite Mail.Send Chat.ReadWrite User.Read.All Sites.Read.All Files.ReadWrite.All ChannelMessage.Read.All ChannelMessage.Send" }
    @{ Name = "Azure Machine Learning"; AppId = "18a66f5f-dbdf-4c17-9dd7-1634712a9cbe"; Scope = "user_impersonation" }
    @{ Name = "Power Platform API";     AppId = "8578e004-a5c6-46e7-913e-12f58912df43"; Scope = "Connectivity.Connections.Read" }
    @{ Name = "Power BI Service";       AppId = "00000009-0000-0000-c000-000000000000"; Scope = "DataAgent.Read.All DataAgent.Execute.All SemanticModel.Read.All Item.Read.All Workspace.Read.All" }
    @{ Name = "Work IQ";                AppId = "fdcc1f02-fc51-4226-8753-f668596af7f7"; Scope = "WorkIQAgent.Ask" }
    @{ Name = "Agent365Observability";  AppId = "9b975845-388f-4429-889e-eab1ef63949c"; Scope = "Agent365.Observability.OtelWrite" }
)

foreach ($res in $oboResources) {
    $resSP = az ad sp show --id $res.AppId --query id -o tsv 2>$null
    if ([string]::IsNullOrEmpty($resSP)) {
        Write-Host "WARNING: could not resolve SP for $($res.Name) ($($res.AppId)); skipping."
        continue
    }
    $grant = @"
{
  "clientId": "$blueprintSP",
  "consentType": "AllPrincipals",
  "principalId": null,
  "resourceId": "$resSP",
  "scope": "$($res.Scope)"
}
"@
    try {
        Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/oauth2PermissionGrants" `
            -Method Post `
            -Headers @{
                "Content-Type"  = "application/json"
                "Accept"        = "application/json"
                "Authorization" = "Bearer $graphToken"
            } `
            -Body $grant | Out-Null
        Write-Host "$($res.Name): granted [$($res.Scope)] to blueprint SP."
    }
    catch {
        $msg = $_.ErrorDetails.Message
        if ($msg -and ($msg -like "*Permission entry already exists*")) {
            Write-Host "$($res.Name): permission already exists - ignoring."
        }
        else {
            throw
        }
    }
}
