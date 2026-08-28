targetScope = 'resourceGroup'

// =================================================================================================
// Main parameters
// =================================================================================================

@minLength(1)
@maxLength(64)
@description('Name of the application. Used to ensure resource names are unique.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// =================================================================================================
// Project module parameters
// =================================================================================================

@description('Name of the Cognitive Services account')
param accountName string = '${environmentName}acct'

@description('Name of the Cognitive Services project')
param projectName string = '${environmentName}proj'

@description('Name of the Container Registry')
param containerRegistryName string = '${environmentName}acr'

@description('SKU of Cognitive Services account')
param cognitiveServicesSku string = 'S0'

@description('SKU of Container Registry')
@allowed(['Basic', 'Standard', 'Premium'])
param containerRegistrySku string = 'Basic'

param agentName string = 'caldova-supply-autopilot'

// =================================================================================================
// Bot Service module parameters
// =================================================================================================
//
// NOTE: The Azure Bot Service is intentionally NOT created here anymore. With the auto-create
// blueprint model (mirroring the iqdeepdive autopilot), the agent identity blueprint does not
// exist until the hosted agent VERSION is created (blueprint_reference omitted → auto-created).
// The Bot Service needs the blueprint client id as its msaAppId, so it is deployed AFTER the
// agent is deployed, by infra/a365/publish-autopilot.ps1 (which reads the blueprint id back from
// the version-create response / `az` and deploys infra/a365/botservice.bicep).

@description('Model name')
param modelName string = 'gpt-5.4-mini'

@description('Model version')
param modelVersion string = '2026-03-17'

@description('Model deployment capacity (thousands of tokens/min; keep within quota)')
param modelCapacity int = 50

// =================================================================================================
// Provisioning toggles + identity
// =================================================================================================

@description('Object ID of the deploying user (provided automatically by azd)')
param principalId string = ''

@description('Provision an Azure AI Search service for Foundry IQ')
param deploySearch bool = true

@description('Search service name')
param searchServiceName string = '${environmentName}search'

@description('Provision a Microsoft Fabric capacity for Fabric IQ (costs money while running)')
param deployFabricCapacity bool = false

@description('Fabric capacity name')
param fabricCapacityName string = '${environmentName}fabric'

@description('Capacity administrator (object ID or UPN). Defaults to the deploying user.')
param fabricAdminPrincipal string = ''

// =================================================================================================
// Common parameters
// =================================================================================================

@description('Tags to apply to all resources')
param tags object = {}

// =================================================================================================
// Module deployments
// =================================================================================================

// 1. Deploy the project module (Cognitive Services account, project, and Container Registry).
//    This is the ONLY provisioned infrastructure. The agent identity blueprint, instance
//    identity, and Azure Bot Service are all created later (blueprint + instance auto-created by
//    the hosted-agent version-create; Bot Service by infra/a365/publish-autopilot.ps1).
module project 'modules/project.bicep' = {
  name: 'project-deployment'
  params: {
    accountName: accountName
    projectName: projectName
    containerRegistryName: containerRegistryName
    location: location
    tags: tags
    cognitiveServicesSku: cognitiveServicesSku
    containerRegistrySku: containerRegistrySku
    modelName: modelName
    modelVersion: modelVersion
    modelCapacity: modelCapacity
  }
}

// 2. Azure AI Search — backs Foundry IQ (the Caldova knowledge base).
module search 'modules/search.bicep' = if (deploySearch) {
  name: 'search-deployment'
  params: {
    searchServiceName: searchServiceName
    location: location
    userPrincipalId: principalId
    foundryProjectPrincipalId: project.outputs.foundryProjectPrincipalId
    tags: tags
  }
}

// 3. Microsoft Fabric capacity — hosts the Caldova lakehouse + ontology + Data Agent (optional).
module fabric 'modules/fabric.bicep' = if (deployFabricCapacity) {
  name: 'fabric-deployment'
  params: {
    capacityName: fabricCapacityName
    location: location
    adminPrincipal: empty(fabricAdminPrincipal) ? principalId : fabricAdminPrincipal
  }
}

// =================================================================================================
// Outputs - These become environment variables consumed by scripts/post-provision.ps1 (deploy)
// and infra/a365/publish-autopilot.ps1 (Agent 365 registration).
// =================================================================================================

@description('ACR login server endpoint')
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = project.outputs.acrloginServer

output AZURE_AI_PROJECT_ENDPOINT string = project.outputs.foundryProjectEndpoint

output SUBSCRIPTION_ID string = subscription().subscriptionId

output RESOURCE_GROUP string = resourceGroup().name

output LOCATION string = location

output ACCOUNT_NAME string = accountName

output PROJECT_NAME string = projectName

output AGENT_NAME string = agentName

output TENANT_ID string = tenant().tenantId

output PROJECT_PRINCIPAL_ID string = project.outputs.foundryProjectPrincipalId

output MODEL_NAME string = modelName

@description('Azure AI Search endpoint (empty if deploySearch=false)')
output AZURE_AI_SEARCH_SERVICE_ENDPOINT string = deploySearch ? search.outputs.searchServiceEndpoint : ''

@description('Azure AI Search service name (empty if deploySearch=false)')
output AZURE_AI_SEARCH_SERVICE_NAME string = deploySearch ? search.outputs.searchServiceName : ''

@description('Fabric capacity resource ID (empty if deployFabricCapacity=false)')
output FABRIC_CAPACITY_ID string = deployFabricCapacity ? fabric.outputs.capacityId : ''

@description('Fabric capacity name (empty if deployFabricCapacity=false)')
output FABRIC_CAPACITY_NAME string = deployFabricCapacity ? fabric.outputs.capacityName : ''
