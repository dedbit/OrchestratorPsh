# OrchestratorCommon Module

This module serves as a wrapper around the OrchestratorAzure module. It provides backward compatibility for scripts that import OrchestratorCommon.

## Purpose

The OrchestratorCommon module has been refactored into:

1. **OrchestratorAzure** - Contains all Azure-related functionality that was previously in OrchestratorCommon
2. **OrchestratorCommon** - Now acts as a loader that imports OrchestratorAzure and re-exports its functions

This structure allows existing scripts to continue working without modification while providing better organization of code.

## Available Functions

All functions from OrchestratorAzure are automatically exported by this module:

- `Connect-12Azure` - Connects to Azure with the specified tenant and subscription
- `Get-12cKeyVaultSecret` - Retrieves a secret (such as a PAT) from an Azure Key Vault

## Usage

```powershell
# Import the module
Import-Module -Path ".\Modules\OrchestratorCommon"

# Connect to Azure
Connect-12Azure -TenantId "your-tenant-id" -SubscriptionId "your-subscription-id"

# Use the Get-12cKeyVaultSecret function
$pat = Get-12cKeyVaultSecret -SecretName "PAT"
```