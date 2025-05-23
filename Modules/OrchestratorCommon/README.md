# OrchestratorCommon Module

This module provides common functions for the OrchestratorPsh project.

## Functions

- `Get-PATFromKeyVault` - Retrieves a Personal Access Token (PAT) from an Azure Key Vault

## Usage

```powershell
# Import the module
Import-Module -Path ".\Modules\OrchestratorCommon"

# Use the Get-PATFromKeyVault function
$pat = Get-PATFromKeyVault -KeyVaultName "your-keyvault" -SecretName "PAT" -TenantId "your-tenant-id" -SubscriptionId "your-subscription-id"
```
il