@description('Name of the Keycloak container app')
param name string

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags object = {}

@description('Name of the Container Apps environment')
param containerAppsEnvironmentName string

@description('Name of the Azure Container Registry')
param containerRegistryName string

@description('Service name for azd tagging')
param serviceName string = 'keycloak'

@description('Keycloak admin username')
param keycloakAdminUser string = 'admin'

@secure()
@description('Keycloak admin password')
param keycloakAdminPassword string

@description('Whether the container app already exists (for updates)')
param exists bool

@description('User assigned identity name for ACR pull')
param identityName string

resource keycloakIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-10-02-preview' existing = {
  name: containerAppsEnvironmentName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' existing = {
  name: containerRegistryName
}

// Grant the identity ACR pull access
module containerRegistryAccess 'core/security/registry-access.bicep' = {
  name: '${name}-registry-access'
  params: {
    containerRegistryName: containerRegistryName
    principalId: keycloakIdentity.properties.principalId
  }
}

resource existingApp 'Microsoft.App/containerApps@2024-10-02-preview' existing = if (exists) {
  name: name
}

// Keycloak container app with custom image containing realm import
resource keycloakApp 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': serviceName })
  dependsOn: [containerRegistryAccess]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${keycloakIdentity.id}': {} }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'single'
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
      }
      secrets: [
        {
          name: 'keycloak-admin-password'
          value: keycloakAdminPassword
        }
      ]
      registries: [
        {
          server: '${containerRegistry.name}.azurecr.io'
          identity: keycloakIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          image: exists ? existingApp.properties.template.containers[0].image : 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          name: 'keycloak'
          env: [
            {
              name: 'KEYCLOAK_ADMIN'
              value: keycloakAdminUser
            }
            {
              name: 'KEYCLOAK_ADMIN_PASSWORD'
              secretRef: 'keycloak-admin-password'
            }
            {
              name: 'KC_HEALTH_ENABLED'
              value: 'true'
            }
          ]
          resources: {
            cpu: json('2.0')
            memory: '4.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

output identityPrincipalId string = keycloakIdentity.properties.principalId
output name string = keycloakApp.name
output hostName string = keycloakApp.properties.configuration.ingress.fqdn
output uri string = 'https://${keycloakApp.properties.configuration.ingress.fqdn}'
output imageName string = exists ? existingApp.properties.template.containers[0].image : ''
