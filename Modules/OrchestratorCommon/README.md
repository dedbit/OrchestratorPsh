# OrchestratorCommon Module

This module serves as a wrapper around the OrchestratorAzure module. It provides backward compatibility for scripts that import OrchestratorCommon.

## Purpose

The OrchestratorCommon module has been refactored into:

1. **OrchestratorAzure** - Contains all Azure-related functionality that was previously in OrchestratorCommon
2. **OrchestratorCommon** - Now acts as a loader that imports OrchestratorAzure and re-exports its functions

This structure allows existing scripts to continue working without modification while providing better organization of code.

## Available Functions

All functions from OrchestratorAzure are automatically exported by this module:

- `Connect-ToAzure` - Connects to Azure with the specified tenant and subscription
- `Get-PATFromKeyVault` - Retrieves a Personal Access Token (PAT) from an Azure Key Vault

## Usage

```powershell
# Import the module
Import-Module -Path ".\Modules\OrchestratorCommon"

# Connect to Azure
Connect-ToAzure -TenantId "your-tenant-id" -SubscriptionId "your-subscription-id"

# Use the Get-PATFromKeyVault function
$pat = Get-PATFromKeyVault -KeyVaultName "your-keyvault" -SecretName "PAT" -TenantId "your-tenant-id" -SubscriptionId "your-subscription-id"
```
il