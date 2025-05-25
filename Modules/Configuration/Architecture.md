# Configuration Module Architecture

## Project Overview
The Configuration module provides centralized configuration management capabilities for OrchestratorPsh scripts and modules.

## Module Components

### Core Functions

- **Initialize-12Configuration**: Loads configuration from a JSON file and stores it in a global variable for access across scripts.
  
- **Get-PSCommandPath**: Helper function that determines the current execution path, whether running in a script or directly in a terminal.

## Usage

The Configuration module is used to standardize how configuration is accessed throughout the OrchestratorPsh ecosystem:

```powershell
# Import the module
Import-Module -Name ConfigurationPackage

# Initialize configuration (will look for dev.json in the environments folder by default)
Initialize-12Configuration

# Access configuration values
$keyVaultName = $Global:12cConfig.connections.keyVault

# Get the current script/command path (useful for building relative paths)
$currentPath = Get-PSCommandPath
```

## Package Structure

- **ConfigurationPackage.psd1**: Module manifest file containing metadata and exported functions
- **ConfigurationPackage.psm1**: Module implementation containing the actual function code
- **BuildPackage.ps1**: Script for building the NuGet package
- **PublishPackage.ps1**: Script for publishing the NuGet package to a feed
- **Test-Module.ps1**: Basic test script for the module
- **Test-ModuleComprehensive.ps1**: Detailed test script that validates all module functionality

## Dependencies

The Configuration module is self-contained and has no external dependencies beyond PowerShell 5.1.
