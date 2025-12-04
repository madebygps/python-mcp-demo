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
param serviceName string = 'aca'

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

@description('Keycloak realm URL for token validation')
param keycloakRealmUrl string

@description('Base URL of the MCP server (for OAuth metadata)')
param mcpServerBaseUrl string

@description('Expected audience claim in JWT tokens')
param mcpServerAudience string = 'mcp-server'

resource acaIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

module app 'core/host/container-app-upsert.bicep' = {
  name: '${serviceName}-container-app-module'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    identityName: acaIdentity.name
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
        value: acaIdentity.properties.clientId
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
      // Keycloak authentication environment variables
      {
        name: 'KEYCLOAK_REALM_URL'
        value: keycloakRealmUrl
      }
      {
        name: 'MCP_SERVER_BASE_URL'
        value: mcpServerBaseUrl
      }
      {
        name: 'MCP_SERVER_AUDIENCE'
        value: mcpServerAudience
      }
    ]
    targetPort: 8000
  }
}

output identityPrincipalId string = acaIdentity.properties.principalId
output name string = app.outputs.name
output hostName string = app.outputs.hostName
output uri string = app.outputs.uri
output imageName string = app.outputs.imageName
