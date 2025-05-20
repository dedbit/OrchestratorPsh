// main.bicep - Equivalent to main.tf
targetScope = 'subscription'

// Define parameters equivalent to variables in the Terraform file
param githubRepoUrl string = ''

// Resource names, tenant ID, and subscription ID - now loaded from environments/dev.json
param resourceGroupName string
param keyVaultName string
param tenantId string
param subscriptionId string

// Location for the resources
param location string = 'West Europe'

// Object ID for Key Vault access policies
param objectId string

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
  name: 'keyVaultDeployment'
  scope: rg
  params: {
    keyVaultName: keyVaultName
    location: location
    tenantId: tenantId
    objectId: objectId
  }
}

// Output values
output deploymentOutputs object = {
  resourceGroupName: resourceGroupName
  subscriptionId: subscriptionId
  keyVaultName: keyVaultModule.outputs.keyVaultName
}

