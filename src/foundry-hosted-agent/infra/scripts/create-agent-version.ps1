#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Create (or add a version to) the standalone `caldova-supply-hosted-agent` hosted agent.

.DESCRIPTION
  This is a PLAIN Foundry hosted agent — Responses protocol ONLY, Entra auth only,
  and it is **never hired into Teams**. That is what keeps it a normal Foundry
  agent, visible + chattable in the Foundry portal Playground (unlike the Teams
  autopilot, whose inline Playground is disabled once it is published to Teams).

  Like the autopilot, the platform auto-creates an agent identity blueprint +
  instance identity on first version-create (there is no way to opt out in this
  preview). We do NOT run any bot-service / publish step, so it stays a plain
  agent. The container authenticates its Responses call to the IQ project with the
  instance identity, so we pass FOUNDRY_AGENT_DEFAULT_INSTANCE_CLIENT_ID as a
  runtime env var on the second pass (no image rebuild needed — the image bakes no
  identity).

  Required env (set by deploy.ps1 from the azd environment):
    AZURE_AI_PROJECT_ENDPOINT           hosting project endpoint (where the agent runs)
    AGENT_NAME                          caldova-supply-hosted-agent
    AZURE_CONTAINER_REGISTRY_ENDPOINT   ACR login server
    IQ_PROJECT_ENDPOINT                 IQ project endpoint (where the 3 connections live)
    FOUNDRY_MODEL_NAME                  model deployment in the IQ project
    FABRIC_CONNECTION_ID                Fabric IQ project-connection (ARM id)
    FOUNDRY_IQ_CONNECTION_ID            Foundry IQ KB connection name
    FOUNDRY_IQ_MCP_URL                  Foundry IQ KB MCP url
    WEB_IQ_CONNECTION_ID                Web IQ connection name
    WORK_IQ_CONNECTION_ID               Work IQ connection name (optional; parity with autopilot)
    IQ_ACCOUNT_RESOURCE_ID              ARM id of the IQ project's AIServices account
  Optional:
    AGENT_INSTANCE_CLIENT_ID            set on pass 2 to pin the container's MI client id
    AGENT_BLUEPRINT_NAME                set on re-runs to reuse the auto-created blueprint
    IQ_REASONING_EFFORT                 default 'low'
#>
$ErrorActionPreference = "Stop"

$AzureAIProjectEndpoint = $env:AZURE_AI_PROJECT_ENDPOINT
$AgentName = $env:AGENT_NAME
$AcrEndpoint = $env:AZURE_CONTAINER_REGISTRY_ENDPOINT

$agentUrl = "$($AzureAIProjectEndpoint)/agents/$($AgentName)/versions?api-version=2025-11-15-preview"

$envVars = @{
    IQ_PROJECT_ENDPOINT     = "$($env:IQ_PROJECT_ENDPOINT)"
    ModelDeployment         = "$(if ($env:FOUNDRY_MODEL_NAME) { $env:FOUNDRY_MODEL_NAME } else { 'gpt-5.4-mini' })"
    IQ_REASONING_EFFORT     = "$(if ($env:IQ_REASONING_EFFORT) { $env:IQ_REASONING_EFFORT } else { 'low' })"
    FABRIC_CONNECTION_ID    = "$($env:FABRIC_CONNECTION_ID)"
    FABRIC_WORKSPACE_ID     = "$($env:FABRIC_WORKSPACE_ID)"
    FABRIC_DATAAGENT_ID     = "$($env:FABRIC_DATAAGENT_ID)"
    FOUNDRYIQ_CONNECTION_ID = "$($env:FOUNDRY_IQ_CONNECTION_ID)"
    FOUNDRYIQ_MCP_URL       = "$($env:FOUNDRY_IQ_MCP_URL)"
    WEB_IQ_CONNECTION_ID    = "$(if ($env:WEB_IQ_CONNECTION_ID) { $env:WEB_IQ_CONNECTION_ID } else { 'WebIQ' })"
    WORK_IQ_CONNECTION_ID   = "$(if ($env:WORK_IQ_CONNECTION_ID) { $env:WORK_IQ_CONNECTION_ID } else { 'WorkIQ' })"
    # Agentic OBO (real user passthrough) — mint user-delegated tokens for the agent-user.
    TENANT_ID               = "$($env:TENANT_ID)"
    OBO_BLUEPRINT_CLIENT_ID = "$($env:OBO_BLUEPRINT_CLIENT_ID)"
    OBO_BLUEPRINT_SECRET    = "$($env:OBO_BLUEPRINT_SECRET)"
    OBO_INSTANCE_CLIENT_ID  = "$($env:OBO_INSTANCE_CLIENT_ID)"
    OBO_AGENT_USER_ID       = "$($env:OBO_AGENT_USER_ID)"
}
# NOTE: do NOT set FOUNDRY_AGENT_DEFAULT_INSTANCE_CLIENT_ID (or any FOUNDRY_* / AGENT_*
# var) here — the platform reserves them and INJECTS the instance identity client id
# itself. The container reads it at runtime via os.getenv, so no rebuild / pinning is
# needed.
# SECURITY: BLUEPRINT_CLIENT_SECRET is passed inline for the demo. For production, store
# it in Key Vault and have the instance identity read it at runtime instead.

$body = @{
    definition = @{
        kind   = "hosted"
        image  = "$($AcrEndpoint)/caldova-supply-hosted-agent:latest"
        cpu    = "1"
        memory = "2Gi"
        environment_variables = $envVars
        container_protocol_versions = @(
            @{ protocol = "responses"; version = "2.0.0" }
        )
    }
    metadata = @{ enableVnextExperience = "true" }
    description = "Caldova supply analyst — standalone Foundry agent (Web + Foundry + Fabric IQ) for the portal Playground."
    agent_endpoint = @{
        protocols = @("responses")
        authorization_schemes = @(
            @{ "type" = "Entra" }
        )
    }
    # blueprint_reference omitted on first create -> platform auto-creates the
    # agent identity blueprint + instance identity. No bot-service / hire step.
}
if ($env:AGENT_BLUEPRINT_NAME) {
    $body.blueprint_reference = @{
        type         = "ManagedAgentIdentityBlueprint"
        blueprint_id = "$($env:AGENT_BLUEPRINT_NAME)"
    }
}

$jsonBody = $body | ConvertTo-Json -Depth 6

Write-Host "Getting access token for https://ai.azure.com ..."
$token = az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv

$headers = @{
    "Content-Type"     = "application/json"
    "Accept"           = "application/json"
    "Authorization"    = "Bearer $token"
    "Foundry-Features" = "HostedAgents=V1Preview,AgentEndpoints=V1Preview"
}

Write-Host "Creating agent version at: $agentUrl"
$response = Invoke-RestMethod -Uri $agentUrl -Method Post -Headers $headers -Body $jsonBody -ErrorAction Stop

$agentVersion      = $response.version
$agentGuid         = $response.agent_guid
$blueprintClientId = $response.blueprint.client_id
$blueprintName     = $response.blueprint_reference.blueprint_id
$instanceClientId  = $response.instance_identity.client_id
$status            = if ($response.status) { $response.status } else { "Unknown" }

Write-Host "Agent GUID          : $agentGuid"
Write-Host "Agent Version       : $agentVersion"
Write-Host "Blueprint name      : $blueprintName"
Write-Host "Instance client id  : $instanceClientId"

$pollUrl = "$($AzureAIProjectEndpoint)/agents/$($AgentName)/versions/$($agentVersion)?api-version=2025-11-15-preview"
if ($status -ne "active" -and $status -ne "failed") {
    for ($i = 1; $i -lt 30; $i++) {
        Start-Sleep -Seconds 10
        Write-Host "Waiting for provisioning (poll $($i)/30)..."
        try {
            $poll = Invoke-RestMethod -Uri $pollUrl -Method Get -Headers $headers -ErrorAction Stop
            $status = if ($poll.status) { $poll.status } else { "Unknown" }
            if (-not $blueprintClientId) { $blueprintClientId = $poll.blueprint.client_id }
            if (-not $blueprintName)     { $blueprintName     = $poll.blueprint_reference.blueprint_id }
            if (-not $instanceClientId)  { $instanceClientId  = $poll.instance_identity.client_id }
        } catch {
            Write-Host "Poll failed: $($_.Exception.Message)"
        }
        Write-Host "Provisioning status: $status"
        if ($status -eq "active" -or $status -eq "failed") { break }
    }
}
if ($status -ne "active") { throw "Agent version provisioning status is '$status', expected 'active'." }

# Grant Cognitive Services User on the IQ project account to the instance identity so
# its Responses calls (which target the IQ project) resolve.
if ($instanceClientId -and $env:IQ_ACCOUNT_RESOURCE_ID) {
    $cogSvcUser = "a97b65f3-24c7-4388-baec-2e87135dc908"
    Write-Host "Granting Cognitive Services User to instance $instanceClientId on IQ account ..."
    $o = az role assignment create --assignee-object-id (az ad sp show --id $instanceClientId --query id -o tsv 2>$null) `
        --assignee-principal-type ServicePrincipal --role $cogSvcUser --scope $env:IQ_ACCOUNT_RESOURCE_ID 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -or $o -match 'RoleAssignmentExists') { Write-Host "  ok" } else { Write-Host "  WARNING: $o" }
}

return @{
    AgentGuid         = $agentGuid
    AgentVersion      = $agentVersion
    BlueprintName     = $blueprintName
    BlueprintClientId = $blueprintClientId
    InstanceClientId  = $instanceClientId
}
