// keyVault.bicep - Module to deploy Key Vault resources
// This module contains ALL the KeyVault resources from the original Terraform template:
// 1. The KeyVault itself with network rules
// 2. The PAT secret
// 3. The additional access policies
// Nothing has been removed, just moved to this module file
targetScope = 'resourceGroup'

// Parameters
param keyVaultName string
param location string
param tenantId string
param ownerObjectId string
param appObjectId string // Renamed parameter for App Object ID from dev.json

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
        objectId: ownerObjectId
        permissions: {
          secrets: [
            'get'
            'list'
            'set'
            'delete'
          ]
        }
      }
      {
        tenantId: tenantId
        objectId: appObjectId
        permissions: {
          secrets: [
            'get'
            'list'
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
        {
          value: '185.162.105.7'
        }
        {
          value: '185.162.105.5'
        }
      ]
    }
  }
}

// Define KeyVault Secret with empty value only during initial deployment
@description('Whether to create PAT secret with empty value - should be true only during initial deployment')
param createEmptyPat bool = false

resource patSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (createEmptyPat) {
  parent: keyVault
  name: 'PAT'
  properties: {
    value: 'Initialized'
  }
}

// Access Policy for the key vault
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: ownerObjectId
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

// Output the key vault name for use in the parent template
output keyVaultName string = keyVault.name

