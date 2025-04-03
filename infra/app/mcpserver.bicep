@description('Location for the resource.')
param location string = resourceGroup().location

@description('Tags for the resource.')
param tags object = {}

@description('Name of the Container Apps managed environment.')
param containerAppsEnvironmentName string

@description('Name for the App.')
param name string

@description('Name of the container.')
param containerName string = 'mcpserver'

@description('Name of the container registry.')
param containerRegistryName string

@description('Port exposed by the app container.')
param containerPort int

@description('Minimum replica count for app containers.')
param containerMinReplicaCount int

@description('Maximum replica count for app containers.')
param containerMaxReplicaCount int

param mcpserverContainerAppExists bool

var abbrs = loadJsonContent('../abbreviations.json')
var identityName = '${abbrs.managedIdentityUserAssignedIdentities}${name}'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-04-01-preview' existing = {
  name: containerAppsEnvironmentName
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(subscription().id, resourceGroup().id, identity.id, 'acrPullRole')
  properties: {
    roleDefinitionId:  subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // ACR Pull role
    principalType: 'ServicePrincipal'
    principalId: identity.properties.principalId
  }
}

module fetchLatestContainerImage '../shared/fetch-container-image.bicep' = {
  name: '${name}-fetch-image'
  params: {
    exists: mcpserverContainerAppExists
    containerAppName: name
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  tags: union(tags, {'azd-service-name':  'mcpserver' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${identity.id}': {} }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: containerPort
        transport: 'auto'
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: identity.id
        }
      ]
      secrets: [
      ]
    }
    template: {
      containers: [
        {
          name: containerName
          image: fetchLatestContainerImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          env: [
          ]
        }
      ]
      scale: {
        minReplicas: containerMinReplicaCount
        maxReplicas: containerMaxReplicaCount
      }
    }
  }
}

output containerAppName string = containerApp.name
output containerAppFQDN string = containerApp.properties.configuration.ingress.fqdn

