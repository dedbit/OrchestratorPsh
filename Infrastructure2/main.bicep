// main.bicep - Equivalent to main.tf
targetScope = 'resourceGroup'

// Define parameters equivalent to variables in the Terraform file
param githubRepoUrl string = ''

// Resource names, tenant ID, and subscription ID
param resourceGroupName string = 'orchestratorPsh-dev-rg'
param keyVaultName string = 'orchestrator2psh-kv'
param tenantId string = '6df08080-a31a-4efa-8c05-2373fc4515fc'
param subscriptionId string = 'd3e92861-7740-4f9f-8cd2-bdfe8dd4bde3'

// Location for the resources
param location string = 'West Europe'

// Object ID for Key Vault access policies
param objectId string

// Define KeyVault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: objectId // This will be passed from the deployment script
        permissions: {
          secrets: [
            'get'
            'list'
            'set'
            'delete'
          ]
        }
      }
    ]
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: [
        {
          value: '185.162.105.4'
        }
        {
          value: '87.63.79.239'
        }
      ]
    }  }
  tags: {
    GitHubRepo: githubRepoUrl
  }
}

// Define KeyVault Secret
resource patSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'PAT'
  properties: {
    value: ''
  }
}

// Access Policy for the key vault
// Note: In Bicep, additional access policies can be added directly to the keyVault resource
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: objectId // Using the parameter passed from deployment script
        permissions: {
          secrets: [
            'get'
            'list'
            'set'
            'delete'
            'recover'
            'backup'
            'restore'
          ]
        }
      }
    ]
  }
}

// Output values
output deploymentOutputs object = {
  resourceGroupName: resourceGroupName
  subscriptionId: subscriptionId
  keyVaultName: keyVaultName
}
