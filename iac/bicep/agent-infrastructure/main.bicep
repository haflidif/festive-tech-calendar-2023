//Define parameters
// https://github.com/haflidif/festive-tech-calendar-2023
param nameprefix string
@description('Prefix for all resources created by this template.')
param systemname string
@description('Name of the system. Used for naming resources.')
param location string = resourceGroup().location
@description('The location where the resources will be deployed')
@secure()
param azdoPat string
@description('The Azure DevOps Personal Access Token. Used to authenticate to Azure DevOps from KEDA Scaler, as User Assigned Identity is not yet supported.')
param poolName string
@description('The name of the AzureDevOps agent pool.')
param azdoUrl string
@description('The URL of the Azure DevOps organization.')
param gitrepo string
@description('The URL of the git repository where the docker file and start.sh script are located.')
param dockerfile string
@description('The name of the docker file to be used for the container')
param imageName string
@description('The name of the image to be used for the container.')
param userAssignedIdentityName string
@description('The name of the user assigned identity.')
param vnetAddressPrefixes array
@description('The address prefix for the virtual network.')
param sharedServiceSubnet object
@description('The subnet for shared services.')
param containerAppSubnet object
@description('The subnet for the container app environment.')
param tags object = {}
@description('Tags to be applied to all resources.')

//Naming Parameters
param vnetName string = '${nameprefix}-${systemname}-vnet'
@description('The name of the virtual network.')
param lawName string = '${nameprefix}-${systemname}-law'
@description('The name of the Log Analytics Workspace.')
param acrName string = '${nameprefix}${systemname}acr'
@description('The name of the Azure Container Registry.')
param containerAppEnvName string = '${nameprefix}-${systemname}-cnappenv'
@description('The name of the container app environment.')

// Getting information about User Assigned Identity
resource usrami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: userAssignedIdentityName
}

//Creating Virtual Network for the Container App Environment
resource containerappvnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: vnetAddressPrefixes
    }
    subnets: [ sharedServiceSubnet, containerAppSubnet ]
  }
}

// Defining Log Analytics Workspace for gathering logs from the Container App Environment.
resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${lawName}-${(uniqueString(resourceGroup().id))}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Defining Azure KeyVault for storing PAT token to use with KEDA Scaler.
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${nameprefix}-${systemname}-kv'
  location: location
  tags: tags

  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: [
        {
          id: containerappvnet.properties.subnets[1].id
          ignoreMissingVnetServiceEndpoint: false
        }
        {
          id: containerappvnet.properties.subnets[0].id
          ignoreMissingVnetServiceEndpoint: false
        }
      ]
    }
    publicNetworkAccess: 'Enabled'
    enableRbacAuthorization: true
    accessPolicies: []
    enableSoftDelete: false // Would change this to true for production workloads.
    enabledForTemplateDeployment: true 
  }
}

resource kvpatsecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'personal-access-token'
  parent: kv
  properties: {
    value: azdoPat
  }
}

// Getting Key Vault Administrator built-in role definition.
resource keyvaultadminRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
  scope: subscription()
}

// Defining KeyVault Secrets Administrator role assignment for the User Assigned Identity.
resource kvroleassignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().subscriptionId, 'kvroleassignment', keyvaultadminRoleDefinition.id)
  scope: kv
  properties: {
    principalId: usrami.properties.principalId
    roleDefinitionId: keyvaultadminRoleDefinition.id
  }
}

//Creating Managed Environment resources.
resource containerappenv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppEnvName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: law.properties.customerId
        sharedKey: law.listKeys().primarySharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: containerappvnet.properties.subnets[1].id
      internal: true
    }
    zoneRedundant: true
  }
}

// Defining Diagnostic Settings for the Container App Environment
resource containerappenvdiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'containerappenvdiag'
  scope: containerappenv
  properties: {
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    workspaceId: law.id
  }
}

// Defining Container Registry.

resource acr 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: acrName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${usrami.id}': {}
    }
  }
  sku: {
    name: 'Basic'
    //Premium SKU is required for private endpoints.
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
    // Required for the deployment script to build the images. Public Network Access, can be disabled after the deployment.
    networkRuleBypassOptions: 'AzureServices'
  }
}

// Defining Deployment Script for the ACR Build
resource arcbuild 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'acrbuild'
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${usrami.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.53.0'
    retentionInterval: 'P1D'
    timeout: 'PT30M'
    arguments: '${acr.name} ${imageName} ${dockerfile} ${gitrepo}'
    scriptContent: '''
    az login --identity
    az acr build --registry $1 --image $2 --file $3 $4
    '''
    cleanupPreference: 'OnSuccess'
 }
}

// Defining Placeholder Azure DevOps Agent in the Pool so jobs can be run, and scaled automatically.
resource arcplaceholder 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'acrplaceholder'
  location: location
  tags: union(tags, { Note: 'Can be deleted after original ADO registration (along with the Placeholder Job). Although the Azure resource can be deleted, Agent placeholder in ADO cannot be.' })
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${usrami.id}': {}
    }
  }

  properties: {
    azCliVersion: '2.53.0'
    retentionInterval: 'P1D'
    timeout: 'PT30M'
    arguments: '${acr.name} ${imageName} ${poolName} ${resourceGroup().name} ${azdoUrl} ${usrami.properties.clientId} ${containerappenv.name} ${usrami.id}'
    scriptContent: '''
    az login --identity
    az extension add --name containerapp --upgrade --only-show-errors
    az containerapp job create -n 'placeholder' -g $4 --environment $7 --trigger-type Manual --replica-timeout 300 --replica-retry-limit 1 --replica-completion-count 1 --parallelism 1 --image "$1.azurecr.io/$2" --cpu "2.0" --memory "4Gi" --secrets "organization-url=$5" --env-vars "USRMI_ID=$6" "AZP_URL=$5" "AZP_POOL=$3" "AZP_PLACEHOLDER=1" "AZP_AGENT_NAME=dontdelete-placeholder-agent" --registry-server "$1.azurecr.io" --registry-identity "$8"
    az containerapp job start -n "placeholder" -g $4
    '''
    cleanupPreference: 'OnSuccess'
  }
  dependsOn: [
    arcbuild
    containerappenvdiag
  ]
}

// Defining Container App Service Job for Azure DevOps Agent with KEDA Scaler configuration.
resource azdoagentjob 'Microsoft.App/jobs@2023-05-02-preview' = {
  name: 'azdoagentjob'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${usrami.id}': {}
    }
  }
  properties: {
    environmentId: containerappenv.id

    configuration: {
      triggerType: 'Event'

      secrets: [
        {
          name: 'organization-url'
          value: azdoUrl
        }
        {
          name: 'personal-access-token'
          keyVaultUrl: kvpatsecret.properties.secretUri
          identity: usrami.id
        }
        {
          name: 'azp-pool'
          value: poolName
        }
        {
          name: 'user-assigned-identity-client-id'
          value: usrami.properties.clientId
        }
      ]
      replicaTimeout: 1800
      replicaRetryLimit: 1
      eventTriggerConfig: {
        replicaCompletionCount: 1
        parallelism: 1
        scale: {
          minExecutions: 0
          maxExecutions: 10
          pollingInterval: 30
          rules: [
            {
              name: 'azure-pipelines'
              type: 'azure-pipelines'

              // https://keda.sh/docs/2.11/scalers/azure-pipelines/
              metadata: {
                poolName: poolName
                targetPipelinesQueueLength: '1'
              }
              auth: [
                {
                  secretRef: 'personal-access-token'
                  triggerParameter: 'personalAccessToken'
                }
                {
                  secretRef: 'organization-url'
                  triggerParameter: 'organizationURL'
                }
              ]
            }
          ]
        }
      }
      registries: [
        {
          server: acr.properties.loginServer
          identity: usrami.id
        }
      ]
    }
    template: {
      containers: [
        {
          image: '${acr.properties.loginServer}/${imageName}'
          name: 'azdoagent'
          env: [
            {
              name: 'USRMI_ID'
              secretRef: 'user-assigned-identity-client-id'
            }
            {
              name: 'AZP_URL'
              secretRef: 'organization-url'
            }
            {
              name: 'AZP_POOL'
              secretRef: 'azp-pool'
            }
          ]
          resources: {
             cpu: 2
             memory: '4Gi'
          }
        }
      ]
    }
  }
  dependsOn: [
    arcplaceholder
    containerappenvdiag
  ]
}

// Defining Outputs to use in the Terraform Infrastructure Bicep Template.
output vnetId string = containerappvnet.id
output vnetName string = containerappvnet.name
output containerSubnetId string = containerappvnet.properties.subnets[1].id
