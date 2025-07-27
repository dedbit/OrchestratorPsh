# OrchestratorAzure Module

This module provides Azure-related functions for the OrchestratorPsh project.

## Functions

- `Connect-12Azure` - Connects to Azure using 12c configuration
- `Get-12cKeyVaultSecret` - Retrieves a secret (such as a PAT) from an Azure Key Vault

## Usage

```powershell
# Import the module
Import-Module -Path ".\Modules\OrchestratorAzure"

# Connect to Azure
Connect-12Azure

# Use the Get-12cKeyVaultSecret function
$pat = Get-12cKeyVaultSecret -SecretName "PAT"
```
