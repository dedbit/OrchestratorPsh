# OrchestratorAzure Module

This module provides Azure-related functions for the OrchestratorPsh project.

## Functions

- `Connect-ToAzure` - Connects to Azure with the specified tenant and subscription
- `Get-PATFromKeyVault` - Retrieves a Personal Access Token (PAT) from an Azure Key Vault

## Usage

```powershell
# Import the module
Import-Module -Path ".\Modules\OrchestratorAzure"

# Connect to Azure
Connect-ToAzure -TenantId "your-tenant-id" -SubscriptionId "your-subscription-id"

# Use the Get-PATFromKeyVault function
$pat = Get-PATFromKeyVault -KeyVaultName "your-keyvault" -SecretName "PAT" -TenantId "your-tenant-id" -SubscriptionId "your-subscription-id"
```
il