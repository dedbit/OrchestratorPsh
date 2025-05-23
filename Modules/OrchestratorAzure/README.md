# OrchestratorAzure Module

This module provides Azure-related functions for the OrchestratorPsh project.

## Functions

- `Connect-12Azure` - Connects to Azure using 12c configuration
- `Get-PATFromKeyVault` - Retrieves a Personal Access Token (PAT) from an Azure Key Vault

## Usage

```powershell
# Import the module
Import-Module -Path ".\Modules\OrchestratorAzure"

# Connect to Azure
Connect-12Azure

# Use the Get-PATFromKeyVault function
$pat = Get-PATFromKeyVault -KeyVaultName "your-keyvault" -SecretName "PAT" -TenantId "your-tenant-id" -SubscriptionId "your-subscription-id"
```
