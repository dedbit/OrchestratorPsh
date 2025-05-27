// main.bicep - Equivalent to main.tf
targetScope = 'subscription'

// Define parameters equivalent to variables in the Terraform file
param githubRepoUrl string = ''

// Resource names, tenant ID, and subscription ID - now loaded from environments/dev.json
param resourceGroupName string
param keyVaultName string
param storageAccountName string
param tenantId string
param subscriptionId string

// Location for the resources
param location string = 'West Europe'

// Object ID for Key Vault access policies
param ownerObjectId string

// App ID for Key Vault access policies (from dev.json)
param appObjectId string



// Define Resource Group with tag - this places the GitHub repo tag on the resource group
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: {
    GitHubRepo: githubRepoUrl
  }
}

// Deploy Key Vault resources using a module
// This module contains the KeyVault, KeyVault Secret, and Access Policies
// We use a module because these resources need to be deployed at resource group scope
// while the resource group itself needs to be deployed at subscription scope
module keyVaultModule 'keyVault.bicep' = {
  name: 'keyVaultModule'
  scope: rg
  params: {
    keyVaultName: keyVaultName
    location: location
    tenantId: tenantId
    ownerObjectId: ownerObjectId
    appObjectId: appObjectId
  }
}

// Deploy Storage Account resources using a module
module storageModule 'storageAccount.bicep' = {
  name: 'storageAccountDeployment'
  scope: rg
  params: {
    location: location
    githubRepoUrl: githubRepoUrl
    storageAccountName: storageAccountName
  }
}

// Output values
output deploymentOutputs object = {
  resourceGroupName: resourceGroupName
  subscriptionId: subscriptionId
  keyVaultName: keyVaultModule.outputs.keyVaultName
  storageAccountName: storageModule.outputs.storageAccountName
  appId: appObjectId                // Reference the parameter to avoid unused parameter warning
}


