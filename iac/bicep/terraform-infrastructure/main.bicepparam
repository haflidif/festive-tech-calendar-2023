using './main.bicep'

param nameprefix = '<YOUR PREFIX HERE>'
param systemname = 'tf'
param containerSubnetId = ''
param vnetAddressPrefixes = ['10.1.0.0/16']
param subnet = {
  name: '${nameprefix}-${systemname}-tf-sn'
  properties: {
    addressPrefix: '10.1.0.0/24'
    serviceEndpoints: [
      {
        locations: [
          'westeurope'
        ]
        service: 'Microsoft.KeyVault'
      }
      {
        locations: [
          'westeurope'
        ]
        service: 'Microsoft.Storage'
      }
    ]
  }
}

param tags = {
  environment: 'terraform-infra'
  createdBy: 'Bicep'
}

