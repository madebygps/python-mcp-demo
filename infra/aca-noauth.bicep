// MCP Server WITHOUT Keycloak authentication (deployed_mcp.py)

@description('Name of the MCP server container app')
param name string

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags object = {}

@description('User assigned identity name for ACR pull and Azure service access')
param identityName string

@description('Name of the Container Apps environment')
param containerAppsEnvironmentName string

@description('Name of the Azure Container Registry')
param containerRegistryName string

@description('Service name for azd tagging')
param serviceName string = 'mcpnoauth'

@description('Whether the container app already exists (for updates)')
param exists bool

@description('Azure OpenAI deployment name')
param openAiDeploymentName string

@description('Azure OpenAI endpoint URL')
param openAiEndpoint string

@description('Cosmos DB account name')
param cosmosDbAccount string

@description('Cosmos DB database name')
param cosmosDbDatabase string

@description('Cosmos DB container name')
param cosmosDbContainer string

resource mcpNoAuthIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

module app 'core/host/container-app-upsert.bicep' = {
  name: '${serviceName}-container-app-module'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    identityName: mcpNoAuthIdentity.name
    exists: exists
    containerAppsEnvironmentName: containerAppsEnvironmentName
    containerRegistryName: containerRegistryName
    ingressEnabled: true
    env: [
      {
        name: 'AZURE_OPENAI_CHAT_DEPLOYMENT'
        value: openAiDeploymentName
      }
      {
        name: 'AZURE_OPENAI_ENDPOINT'
        value: openAiEndpoint
      }
      {
        name: 'RUNNING_IN_PRODUCTION'
        value: 'true'
      }
      {
        name: 'AZURE_CLIENT_ID'
        value: mcpNoAuthIdentity.properties.clientId
      }
      {
        name: 'AZURE_COSMOSDB_ACCOUNT'
        value: cosmosDbAccount
      }
      {
        name: 'AZURE_COSMOSDB_DATABASE'
        value: cosmosDbDatabase
      }
      {
        name: 'AZURE_COSMOSDB_CONTAINER'
        value: cosmosDbContainer
      }
    ]
    targetPort: 8000
  }
}

output identityPrincipalId string = mcpNoAuthIdentity.properties.principalId
output name string = app.outputs.name
output hostName string = app.outputs.hostName
output uri string = app.outputs.uri
output imageName string = app.outputs.imageName
