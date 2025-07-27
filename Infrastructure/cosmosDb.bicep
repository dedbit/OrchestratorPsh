// cosmosDb.bicep - Module to deploy Cosmos DB resources
targetScope = 'resourceGroup'

// Parameters
param location string
param githubRepoUrl string = ''
param cosmosDbAccountName string

// Define Cosmos DB Account with serverless capacity (cheapest option)
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosDbAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
      }
    }
  }
  tags: {
    GitHubRepo: githubRepoUrl
    purpose: 'orchestrator-data'
  }
}

// Define SQL Database
resource sqlDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: cosmosDbAccount
  name: 'OrchestratorDb'
  properties: {
    resource: {
      id: 'OrchestratorDb'
    }
  }
}

// Define Items Container
resource itemsContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = {
  parent: sqlDatabase
  name: 'Items'
  properties: {
    resource: {
      id: 'Items'
      partitionKey: {
        paths: ['/partitionKey']
        kind: 'Hash'
      }
    }
  }
}

// Output the Cosmos DB account name and ID for use in other resources
output cosmosDbAccountName string = cosmosDbAccount.name
output cosmosDbAccountId string = cosmosDbAccount.id