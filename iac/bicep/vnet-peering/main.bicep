targetScope = 'resourceGroup'

param firstVnetRg string
param secondVnetRg string
param firstVnetName string
param secondVnetName string


module peerFirstVnetSecondVnet 'peering.bicep' = {
  name: 'peerFirstToSecond'
  scope: resourceGroup(firstVnetRg)
  params: {
    peeringName: '${firstVnetName}-to-${secondVnetName}'
    existingLocalVirtualNetworkName: firstVnetName
    existingRemoteVirtualNetworkName: secondVnetName
    existingRemoteVirtualNetworkResourceGroupName: secondVnetRg
  }
}

module peerSecondVnetFirstVnet 'peering.bicep' = {
  name: 'peerSecondToFirst'
  scope: resourceGroup(secondVnetRg)
  params: {
    peeringName: '${secondVnetName}-to-${firstVnetName}'
    existingLocalVirtualNetworkName: secondVnetName
    existingRemoteVirtualNetworkName: firstVnetName
    existingRemoteVirtualNetworkResourceGroupName: firstVnetRg
  }
}
