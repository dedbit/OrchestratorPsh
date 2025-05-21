// storageAccount.bicep - Module to deploy storage account resources
targetScope = 'resourceGroup'

// Parameters
param location string
param githubRepoUrl string = ''

// Define Storage Account with a more unique name
resource testaccountsa 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'orchpsh${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
  tags: {
    GitHubRepo: githubRepoUrl
    purpose: 'test'
  }
}

// Output the storage account name and id for potential use in other resources
output storageAccountName string = testaccountsa.name
output storageAccountId string = testaccountsa.id
