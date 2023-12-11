//Define parameters
// https://github.com/haflidif/festive-tech-calendar-2023
param nameprefix string
@description('Prefix for all resources created by this template.')
param systemname string
@description('Name of the system. Used for naming resources.')
param location string = resourceGroup().location
@description('The location where the resources will be deployed')
param containerSubnetId string
@description('Container Subnet ID used for allowing communications through Service Endpoints to the Storage account')
param tags object = {}
@description('Tags to be applied to all resources.')
// param userAssignedIdentityName string = ''
// @description('The name of the user assigned identity.')
param vnetAddressPrefixes array
@description('The address prefixes for the virtual network.')
param subnet object
@description('The subnet to be created in the virtual network.')

//Naming Parameters
param vnetName string = '${nameprefix}-${systemname}-vnet'
@description('The name of the virtual network.')
param storageAccountName string = substring('${nameprefix}${systemname}sa${uniqueString(resourceGroup().id)}', 0, 24)
@description('The name of the storage account.')
param storageContainerName string = 'terraform-state'

// Getting information about User Assigned Identity
// resource usrami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
//   name: userAssignedIdentityName
// }

//Creating Virtual Network for the Container App Environment
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: vnetAddressPrefixes
    }
    subnets: [ subnet ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: [
        {
          action: 'Allow'
          id: containerSubnetId
        }
      ]
    }
    publicNetworkAccess: 'Enabled'
  }
}

resource storageBlobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: storageAccount
  properties: {}
}

resource terraformStateContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: storageContainerName
  parent: storageBlobService
  properties: {
    publicAccess: 'None'
  }
}

// Defining the outputs
output vnetId string = vnet.id
output vnetName string = vnet.name
