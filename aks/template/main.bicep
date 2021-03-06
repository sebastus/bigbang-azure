targetScope = 'subscription'

param resGroupName string = 'bigbang'
param location string = 'northeurope'
param suffix string = 'bigbang-${substring(uniqueString(resGroupName), 0, 4)}'

param enableMonitoring bool = true

param kube object = {
  version: '1.20.7'
  nodeSize: 'Standard_D4_v4'
  nodeCount: 3
  nodeCountMax: 10
}

resource resGroup 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: resGroupName
  location: location  
}

module network 'modules/network.bicep' = {
  scope: resGroup
  name: 'network'
  params: {
    location: location
    suffix: suffix
  }
}

module other 'modules/monitoring.bicep' = if(enableMonitoring) {
  scope: resGroup
  name: 'monitors'
  params: {
    location: location
    suffix: suffix
  }
}

module aks 'modules/aks.bicep' = {
  scope: resGroup
  name: 'aks'
  params: {
    location: location
    suffix: suffix
    // Base AKS config like version and nodes sizes
    kube: kube

    // Network details
    netVnet: network.outputs.vnetName
    netSubnet: network.outputs.aksSubnetName
    
    // Optional features
    logsWorkspaceId: enableMonitoring ? other.outputs.logWorkspaceId : ''
  }
}

output clusterName string = aks.outputs.clusterName
output clusterFQDN string = aks.outputs.clusterFQDN
output aksState string = aks.outputs.provisioningState
