@description('Set the peering name')
param peeringName string

@description('Set the local VNet name')
param existingLocalVirtualNetworkName string

@description('Set the remote VNet name')
param existingRemoteVirtualNetworkName string

@description('Sets the remote VNet Resource group')
param existingRemoteVirtualNetworkResourceGroupName string

resource existingLocalVirtualNetworkName_peering_to_remote_vnet 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-02-01' = {
  name: '${existingLocalVirtualNetworkName}/${peeringName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: resourceId(existingRemoteVirtualNetworkResourceGroupName, 'Microsoft.Network/virtualNetworks', existingRemoteVirtualNetworkName)
    }
  }
}
