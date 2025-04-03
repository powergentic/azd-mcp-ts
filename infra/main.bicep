targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('The Azure region for all resources.')
param location string

@description('Name of the resource group to create or use')
param resourceGroupName string 

@description('Port exposed by the app container.')
param containerPort int = 80

@description('Minimum replica count for app containers.')
param containerMinReplicaCount int = 2

@description('Maximum replica count for app containers.')
param containerMaxReplicaCount int = 3

param mcpserverContainerAppExists bool

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, resourceGroupName, environmentName, location))
var tags = {
  'azd-env-name': environmentName
  'azd-template': 'https://github.com/powergentic/azd-mcp-ts'
}

var containerAppName = '${abbrs.appContainerApps}mcp-${resourceToken}'

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module monitoring './shared/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    tags: tags
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}mcp-${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}mcp-${resourceToken}'
  }
  scope: rg
}

module containerRegistry './shared/container-registry.bicep' = {
  name: 'cotainer-registry'
  params: {
    location: location
    tags: tags
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
  }
  scope: rg
}

module appsEnv './shared/apps-env.bicep' = {
  name: 'apps-env'
  params: {
    name: '${abbrs.appManagedEnvironments}mcp-${resourceToken}'
    location: location
    tags: tags 
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
  }
  scope: rg
}

// Deploy MCP Server Container App via module call.
module mcpserver './app/mcpserver.bicep' = {
  name: 'mcpserver'
  params: {
    name: containerAppName
    containerAppsEnvironmentName: appsEnv.outputs.name

    mcpserverContainerAppExists: mcpserverContainerAppExists

    containerRegistryName: containerRegistry.outputs.name
    containerPort: containerPort
    containerMinReplicaCount: containerMinReplicaCount
    containerMaxReplicaCount: containerMaxReplicaCount
  }
  scope: rg
}


output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
