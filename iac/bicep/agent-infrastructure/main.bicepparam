using './main.bicep'

param nameprefix = '<YourPrefixHere>'
param systemname = 'adoagent'
param location = 'westeurope'
param poolName = '${nameprefix}-containerapp-adoagent'
param azdoUrl = 'https://dev.azure.com/<YourOrgHere>' // https://dev.azure.com/contoso This is the URL to your Azure DevOps organization, where you want to register the agent.
param azdoPat = '<REPLACE WITH YOUR PAT>' // This is the PAT token to authenticate to Azure DevOps, for running KEDA ScaleJob to scale the agent pool, as Managed Identity is not supported for this yet but is on the roadmap (https://github.com/microsoft/azure-container-apps/issues/592).
param gitrepo = 'https://github.com/haflidif/festive-tech-calendar-2023.git#:.ado/ado-pipelines-agent' // If start.sh and dockerfile are not in the root of the repo, you need to specify it by appending #:path/path' etc depending on your folder structure, at the end of the gitrepo url.
param dockerfile = 'dockerfile.ado-pipeline'
param imageName = 'adoagent:1.0'
param vnetAddressPrefixes = [ '10.0.0.0/16']
param userAssignedIdentityName = ''


param sharedServiceSubnet = {
  name: '${nameprefix}-${systemname}-shrsvc-sn'
  properties: {
    addressPrefix: '10.0.0.0/24'
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

param containerAppSubnet = {
  name: '${nameprefix}-${systemname}-cnapp-sn'
  properties: {
    addressPrefix: '10.0.2.0/23'
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
  environment: 'azdo-agent'
  createdBy: 'Bicep'
}
