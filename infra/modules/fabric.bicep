// =================================================================================================
// Microsoft Fabric capacity — hosts the Caldova lakehouse, semantic model, ontology, Data Agent.
//
// Optional (deployFabricCapacity). The deploying user is set as a capacity administrator so the
// postprovision hook can create the Fabric workspace on it and run the data scripts.
//
// Modeled on microsoft/Build26-LAB532 infra/main.bicep.
//
// NOTE: a Fabric *capacity* is provisioned here, but a Fabric *workspace* is created by the
// postprovision hook via the Fabric REST API (workspaces are not ARM/Bicep resources).
// =================================================================================================

@description('Name of the Fabric capacity')
param capacityName string

@description('Location for the Fabric capacity')
param location string

@description('Fabric capacity SKU (F2 is the smallest)')
@allowed(['F2', 'F4', 'F8', 'F16', 'F32', 'F64'])
param skuName string = 'F2'

@description('Object ID or UPN of the deploying user, set as capacity administrator')
param adminPrincipal string

resource fabricCapacity 'Microsoft.Fabric/capacities@2023-11-01' = {
  name: capacityName
  location: location
  sku: {
    name: skuName
    tier: 'Fabric'
  }
  properties: {
    administration: {
      members: [
        adminPrincipal
      ]
    }
  }
}

output capacityName string = fabricCapacity.name
output capacityId string = fabricCapacity.id
