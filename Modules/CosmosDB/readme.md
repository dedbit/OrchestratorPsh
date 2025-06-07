# CosmosDB PowerShell Module

## Installation

Install required packages for development:

```cmd
winget install Microsoft.PowerShell Microsoft.AzureCLI
```

For Azure PowerShell modules (required for production use):

```powershell
Install-Module -Name Az.KeyVault -Scope CurrentUser
Install-Module -Name Az.Accounts -Scope CurrentUser
```

## How to Start Debugging

1. Import the Configuration module to load environment settings
2. Import the CosmosDB module 
3. Initialize configuration to load connection details from Key Vault
4. Use the CosmosDB functions to interact with your database

```powershell
# Import required modules
Import-Module .\Modules\Configuration\ConfigurationPackage\ConfigurationPackage.psd1
Import-Module .\Modules\CosmosDB\CosmosDBPackage\CosmosDBPackage.psd1

# Initialize configuration
Initialize-12Configuration

# Use CosmosDB functions
$item = Get-12cItem -Id "item123"
Set-12cItem -Item @{ id = "item123"; name = "Test Item"; value = 42 }
```

## Configuration Files

- **CosmosDBPackage.psd1** - PowerShell module manifest
- **CosmosDBPackage.nuspec** - NuGet package specification  
- **build.ps1** - Build script for creating the NuGet package
- **publish.ps1** - Script for publishing to NuGet feeds
- **test-module.ps1** - Basic test script
- **test-module-comprehensive.ps1** - Detailed test script
- **environments/dev.json** - Environment configuration with CosmosDB account details

## Architecture Overview

### Components

- **CosmosDBPackage.psm1** - Main module with CosmosDB operations functions
- **Build Scripts** - Automated build, publish, and test processes
- **NuGet Package** - Self-contained distribution format including Az.CosmosDB dependencies
- **REST API Integration** - Direct CosmosDB REST API calls for item operations

### Key Functions

- **Get-12cCosmosConnection** - Retrieves CosmosDB connection details from Azure Key Vault
- **Get-12cItem** - Gets an item from CosmosDB by ID with optional partition key
- **Set-12cItem** - Sets/upserts an item in CosmosDB with automatic JSON conversion

For detailed architecture information, see [Architecture.md](Architecture.md).