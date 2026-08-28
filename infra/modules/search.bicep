// =================================================================================================
// Azure AI Search — backs Foundry IQ (the Caldova knowledge base).
//
// Provisions the Search service and the role assignments the demo needs:
//   * the deploying user  -> Search Service Contributor + Search Index Data Contributor/Reader
//   * the Foundry project MI -> Search Index Data Reader (KB MCP access via ProjectManagedIdentity)
//   * the Search MI -> Cognitive Services OpenAI User + Azure AI User (agentic retrieval)
//
// Modeled on microsoft/Build26-LAB532 infra/main.bicep.
// =================================================================================================

@description('Name of the Azure AI Search service')
param searchServiceName string

@description('Location for the Search service')
param location string

@description('Search service SKU')
@allowed(['basic', 'standard', 'standard2', 'standard3'])
param searchServiceSku string = 'standard'

@description('Object ID of the deploying user (azd principalId)')
param userPrincipalId string

@description('Object ID of the Foundry project managed identity')
param foundryProjectPrincipalId string

@description('Tags to apply')
param tags object = {}

// Built-in role definition IDs
var roleSearchServiceContributor   = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7ca78c08-252a-4471-8644-bb5ff32d4ba0')
var roleSearchIndexDataContributor = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8ebe5a00-799e-43f5-93ac-243d3dce84a7')
var roleSearchIndexDataReader      = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1407120a-92aa-4202-b7e9-c0e197c71c8f')
var roleCognitiveServicesOpenAIUser = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
var roleAzureAIUser                = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '53ca6127-db72-4b80-b1b0-d745d6d5456d')

resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: searchServiceName
  location: location
  tags: tags
  sku: {
    name: searchServiceSku
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'enabled'
    disableLocalAuth: false
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    semanticSearch: 'standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// --- Deploying user ---------------------------------------------------------
resource userSearchContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchService.id, userPrincipalId, roleSearchServiceContributor)
  scope: searchService
  properties: {
    principalId: userPrincipalId
    principalType: 'User'
    roleDefinitionId: roleSearchServiceContributor
  }
}

resource userSearchIndexDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchService.id, userPrincipalId, roleSearchIndexDataContributor)
  scope: searchService
  properties: {
    principalId: userPrincipalId
    principalType: 'User'
    roleDefinitionId: roleSearchIndexDataContributor
  }
}

resource userSearchIndexDataReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchService.id, userPrincipalId, roleSearchIndexDataReader)
  scope: searchService
  properties: {
    principalId: userPrincipalId
    principalType: 'User'
    roleDefinitionId: roleSearchIndexDataReader
  }
}

// --- Foundry project managed identity (KB MCP access) -----------------------
resource projectSearchIndexDataReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchService.id, foundryProjectPrincipalId, roleSearchIndexDataReader)
  scope: searchService
  properties: {
    principalId: foundryProjectPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleSearchIndexDataReader
  }
}

// --- Search service managed identity (agentic retrieval → the model) --------
resource searchToOpenAIUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, searchService.id, roleCognitiveServicesOpenAIUser)
  properties: {
    principalId: searchService.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleCognitiveServicesOpenAIUser
  }
}

resource searchToAzureAIUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, searchService.id, roleAzureAIUser)
  properties: {
    principalId: searchService.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleAzureAIUser
  }
}

output searchServiceName string = searchService.name
output searchServiceEndpoint string = 'https://${searchService.name}.search.windows.net'
