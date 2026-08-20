  $ErrorActionPreference = "Stop"

  # -----------------------------------------------------------------------------
  # Create (or add a version to) the hosted caldova-supply-autopilot.
  #
  # Auto-create blueprint model (mirrors the iqdeepdive autopilot): we OMIT
  # `blueprint_reference`, so the first version-create auto-provisions the agent
  # identity blueprint + instance identity and returns their client ids. There is
  # no pre-created MAIB bicep anymore.
  #
  # Because the Docker image bakes `CONNECTIONS__SERVICE_CONNECTION__SETTINGS__CLIENTID`
  # (= blueprint appId) at build time, and the blueprint does not exist until this
  # call returns, scripts/post-provision.ps1 runs this TWICE:
  #   pass 1 — image built with a placeholder id; returns the real blueprint +
  #            instance client ids.
  #   pass 2 — image rebuilt with those real ids; a second version is created and
  #            @latest rolls forward to it.
  #
  # Returns a hashtable with the ids so the caller can rebuild + re-invoke.
  # -----------------------------------------------------------------------------

  $AzureAIProjectEndpoint = $env:AZURE_AI_PROJECT_ENDPOINT
  $AgentName = $env:AGENT_NAME
  $AzureContainerRegistryEndpoint = $env:AZURE_CONTAINER_REGISTRY_ENDPOINT

  $agentUrl = "$($AzureAIProjectEndpoint)/agents/$($AgentName)/versions?api-version=2025-11-15-preview"

  $agentCreationBody = @{
      definition = @{
          kind = "hosted"
          image = "$($AzureContainerRegistryEndpoint)/caldova-supply-autopilot:latest"
          cpu = "2"
          memory = "4Gi"
          environment_variables = @{
              # Target the Foundry IQ project (IQ_PROJECT_ENDPOINT) so the project_connection_id
              # references below resolve. Model must be a deployment in that account.
              # NOTE: keys must NOT start with the reserved FOUNDRY_ prefix (the platform
              # injects its own FOUNDRY_* vars pointing at the hosting project), so we use
              # IQ_PROJECT_ENDPOINT / IQ_REASONING_EFFORT / FOUNDRYIQ_* here.
              IQ_PROJECT_ENDPOINT            = "$($env:FOUNDRY_PROJECT_ENDPOINT)"
              ModelDeployment                = "$(if ($env:FOUNDRY_MODEL_NAME) { $env:FOUNDRY_MODEL_NAME } else { 'gpt-5.4-mini' })"
              IQ_REASONING_EFFORT            = "$(if ($env:FOUNDRY_REASONING_EFFORT) { $env:FOUNDRY_REASONING_EFFORT } else { 'low' })"
              # The four IQs — Foundry project connection references.
              FABRIC_CONNECTION_ID           = "$($env:FABRIC_CONNECTION_ID)"
              FOUNDRYIQ_CONNECTION_ID        = "$($env:FOUNDRY_IQ_CONNECTION_ID)"
              FOUNDRYIQ_MCP_URL              = "$($env:FOUNDRY_IQ_MCP_URL)"
              WORK_IQ_CONNECTION_ID          = "$(if ($env:WORK_IQ_CONNECTION_ID) { $env:WORK_IQ_CONNECTION_ID } else { 'WorkIQ' })"
              WEB_IQ_CONNECTION_ID           = "$(if ($env:WEB_IQ_CONNECTION_ID) { $env:WEB_IQ_CONNECTION_ID } else { 'WebIQ' })"
              IQ_MODE                        = "$($env:IQ_MODE)"
          }
          container_protocol_versions = @(
              @{
                  protocol = "activity_protocol"
                  version  = "v1"
              }
              @{
                  # Responses protocol enables the Foundry portal Playground to chat
                  # with this hosted agent (served by /responses in the container).
                  protocol = "responses"
                  version  = "2.0.0"
              }
          )
      }
      metadata = @{
        enableVnextExperience = "true"
      }
      description = "Caldova supply and distribution assurance — hosted A365 autopilot wired to all four IQs."
      agent_endpoint = @{
        protocols = @("responses", "activity")
        authorization_schemes = @(
          @{ "type" = "Entra" }
          @{ "type" = "BotServiceRbac" }
        )
      }
      # NOTE: blueprint_reference intentionally OMITTED — the platform auto-creates
      # the agent identity blueprint + instance identity on first version-create.
      #
      # FORWARD-LOOKING: Azure/azure-rest-api-specs#45588 adds an optional
      # `capabilities` array to CreateAgentVersionRequest, with "DigitalWorker" as its
      # only value today. When that ships, this autopilot should declare:
      #     capabilities = @("DigitalWorker")
      # as a sibling of `definition` / `description` / `agent_endpoint` below.
      # Two gotchas:
      #   1. It is CREATE-TIME ONLY — the spec omits `capabilities` from
      #      UpdateAgentRequest, so it cannot be PATCHed on later (unlike the endpoint
      #      protocols in a365/enable-activity-protocol.ps1). Adding it requires a NEW
      #      agent version, which rolls @latest and forces a Teams re-hire.
      #   2. Not yet available: the PR targets `feature/foundry-release`, and
      #      api-version 2025-11-15-preview returns no `capabilities` field on either
      #      the agent or the version, so sending it now is rejected.
  }

  # On pass 2 the caller sets AGENT_BLUEPRINT_CLIENT_ID so we pin the CONNECTIONS
  # client id via runtime environment_variables too (belt-and-suspenders alongside
  # the rebuilt image). This MUST be the blueprint's app/client id GUID.
  if ($env:AGENT_BLUEPRINT_CLIENT_ID) {
      $agentCreationBody.definition.environment_variables["CONNECTIONS__SERVICE_CONNECTION__SETTINGS__CLIENTID"] = "$($env:AGENT_BLUEPRINT_CLIENT_ID)"
  }

  # Reuse the existing blueprint on re-runs / pass 2. If AGENT_BLUEPRINT_NAME is set we
  # reference it so the platform does NOT auto-create a second blueprint. Omit it only on
  # the very first create so the blueprint + instance identity are auto-provisioned.
  if ($env:AGENT_BLUEPRINT_NAME) {
      $agentCreationBody.blueprint_reference = @{
          type         = "ManagedAgentIdentityBlueprint"
          blueprint_id = "$($env:AGENT_BLUEPRINT_NAME)"
      }
  }

  $jsonBody = $agentCreationBody | ConvertTo-Json -Depth 6

  Write-Host "Getting access token for https://ai.azure.com ..."
  $aiAzureToken = az account get-access-token --resource https://ai.azure.com --query accessToken -o tsv

  $headers = @{
      "Content-Type"  = "application/json"
      "Accept"        = "application/json"
      "Authorization" = "Bearer $aiAzureToken"
      "Foundry-Features" = "HostedAgents=V1Preview,AgentEndpoints=V1Preview"
  }

  Write-Host "Creating agent version at: $agentUrl"
  $response = Invoke-RestMethod -Uri $agentUrl -Method Post -Headers $headers -Body $jsonBody -ErrorAction Stop

  $agentVersion = $response.version
  $agentGuid = $response.agent_guid
  # blueprint.client_id is the app/client id GUID (what Bot Service msaAppId,
  # CONNECTIONS clientid, and `az ad sp show` all need). blueprint_reference.blueprint_id
  # is only the blueprint NAME (used to reference/reuse it).
  $blueprintClientId    = $response.blueprint.client_id
  $blueprintPrincipalId = $response.blueprint.principal_id
  $blueprintName        = $response.blueprint_reference.blueprint_id
  $instanceClientId     = $response.instance_identity.client_id

  Write-Host "Agent GUID          : $agentGuid"
  Write-Host "Agent Version       : $agentVersion"
  Write-Host "Blueprint name      : $blueprintName"
  Write-Host "Blueprint client id : $blueprintClientId"
  Write-Host "Blueprint principal : $blueprintPrincipalId"
  Write-Host "Instance client id  : $instanceClientId"

  # Poll for agent version provisioning status
  $maxRetries = 30
  $delaySeconds = 10
  $provisioningStatus = $response.status
  if (-not $provisioningStatus) { $provisioningStatus = "Unknown" }

  $pollUrl = "$($AzureAIProjectEndpoint)/agents/$($AgentName)/versions/$($agentVersion)?api-version=2025-11-15-preview"

  if ($provisioningStatus -ne "active" -and $provisioningStatus -ne "failed") {
      for ($i = 1; $i -lt $maxRetries; $i++) {
          Write-Host "Waiting ${delaySeconds}s before poll $($i + 1)/${maxRetries}..."
          Start-Sleep -Seconds $delaySeconds
          try {
              $pollResponse = Invoke-RestMethod -Uri $pollUrl -Method Get -Headers $headers -ErrorAction Stop
              $provisioningStatus = $pollResponse.status
              if (-not $provisioningStatus) { $provisioningStatus = "Unknown" }
              if (-not $blueprintClientId)    { $blueprintClientId    = $pollResponse.blueprint.client_id }
              if (-not $blueprintPrincipalId) { $blueprintPrincipalId = $pollResponse.blueprint.principal_id }
              if (-not $blueprintName)        { $blueprintName        = $pollResponse.blueprint_reference.blueprint_id }
              if (-not $instanceClientId)     { $instanceClientId     = $pollResponse.instance_identity.client_id }
          } catch {
              Write-Host "Poll failed: $($_.Exception.Message)"
          }
          Write-Host "Provisioning status: $provisioningStatus"
          if ($provisioningStatus -eq "active" -or $provisioningStatus -eq "failed") { break }
      }
  }

  Write-Host "Agent version provisioned: $provisioningStatus"
  if ($provisioningStatus -ne "active") {
      throw "Agent version provisioning status is '$provisioningStatus', expected 'active'."
  }

  # Grant Cognitive Services User on the foundry account to the instance identity so the
  # agent's Responses calls resolve. (The IQ project connections live in the Foundry IQ project; any cross-project grant is handled separately.)
  if ($instanceClientId) {
      $accountScope = "/subscriptions/$($env:SUBSCRIPTION_ID)/resourceGroups/$($env:RESOURCE_GROUP)/providers/Microsoft.CognitiveServices/accounts/$($env:ACCOUNT_NAME)"
      $cognitiveServicesUserRoleId = "a97b65f3-24c7-4388-baec-2e87135dc908"
      Write-Host "Granting Cognitive Services User to instance $instanceClientId on $accountScope"
      $roleAssignmentOutput = az role assignment create --assignee $instanceClientId --role $cognitiveServicesUserRoleId --scope $accountScope 2>&1 | Out-String
      if ($LASTEXITCODE -eq 0) {
          Write-Host "Cognitive Services User role assignment created."
      } elseif ($roleAssignmentOutput -match "RoleAssignmentExists") {
          Write-Host "Cognitive Services User role assignment already exists, skipping."
      } else {
          Write-Host "WARNING: Cognitive Services User role assignment failed: $roleAssignmentOutput"
      }
  }

  # Return the ids for the caller (two-pass rebuild + downstream A365 registration).
  return @{
      AgentGuid            = $agentGuid
      AgentVersion         = $agentVersion
      BlueprintClientId    = $blueprintClientId
      BlueprintName        = $blueprintName
      BlueprintPrincipalId = $blueprintPrincipalId
      InstanceClientId     = $instanceClientId
  }
