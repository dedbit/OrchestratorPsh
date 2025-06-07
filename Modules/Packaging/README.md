# Packaging PowerShell Module

A self-contained PowerShell module for common packaging and publishing tasks, including NuGet operations. This module includes its own `nuget.exe` binary for independence from system-installed NuGet tools.

## Installation

### Prerequisites

This module requires PowerShell 5.1 or later and .NET Framework 4.0 or later.

### Install Required Development Packages

```powershell
winget install Microsoft.PowerShell Microsoft.DotNet.Framework.DeveloperPack_4
```

### Local Development Installation

1. Build the module package:
   ```powershell
   .\build.ps1
   ```

2. Install locally for testing:
   ```powershell
   .\install-local.ps1
   ```

3. Import and use the module:
   ```powershell
   Import-Module Packaging
   ```

## How to Start Debugging

1. Open PowerShell in the Packaging module directory
2. Import the module directly for development:
   ```powershell
   Import-Module .\Packaging.psd1 -Force
   ```
3. Use PowerShell ISE or VS Code with PowerShell extension for debugging
4. Set breakpoints and run module functions

## Configuration Files

- **Packaging.psd1** - PowerShell module manifest
- **Packaging.nuspec** - NuGet package specification
- **build.ps1** - Build script for creating the NuGet package
- **publish.ps1** - Script for publishing to NuGet feeds
- **install-local.ps1** - Local installation script for development

## Architecture Overview

### Components

- **Packaging.psm1** - Main module with packaging and publishing functions
- **nuget.exe** - Self-contained NuGet executable for independence
- **Build Scripts** - Automated build, publish, and install processes
- **NuGet Package** - Self-contained distribution format

### Key Functions

- **Get-PackageVersionFromNuspec** - Reads version information from NuSpec files
- **Set-PackageVersionIncrement** - Automatically increments package versions
- **Invoke-NuGetPack** - Builds NuGet packages using the internal nuget.exe
- **Ensure-NuGetFeedConfigured** - Configures NuGet feeds with authentication
- **Publish-NuGetPackageAndCleanup** - Publishes packages and cleans up feed configuration
- **Get-NuGetPATFromKeyVault** - Retrieves Personal Access Tokens from Azure Key Vault
- **Confirm-DirectoryExists** - Ensures required directories exist
- **Remove-OldPackageVersions** - Maintains clean package output directories

## Building and Publishing

### Build the Package

```powershell
.\build.ps1
```

This will:
- Increment the version number in both the `.nuspec` and `.psd1` files
- Build the NuGet package using the internal `nuget.exe`
- Clean up old package versions

### Publish to Feed

```powershell
.\publish.ps1 -FeedName "your-feed-name" -SecretName "YourPATSecretName"
```

This requires:
- Azure Key Vault configuration (global `$Global:12cConfig`)
- Personal Access Token stored in Key Vault
- Artifacts feed URL in global configuration

### Install Locally

```powershell
.\install-local.ps1 -Scope CurrentUser -Force
```

## Usage Examples

```powershell
# Import the module
Import-Module Packaging

# Build a package from a nuspec file
Invoke-NuGetPack -NuspecPath "MyPackage.nuspec" -OutputDirectory ".\Output"

# Configure a NuGet feed
Ensure-NuGetFeedConfigured -FeedName "MyFeed" -FeedUrl "https://feed.url" -PAT "your-pat"

# Publish a package
Publish-NuGetPackageAndCleanup -PackagePath ".\Output\MyPackage.1.0.0.nupkg" -FeedName "MyFeed"
```

## Notes

- The module uses robust path construction patterns for cross-platform compatibility
- All NuGet operations use the internal `nuget.exe` by default
- External `nuget.exe` paths can still be specified for custom scenarios
- The module maintains backward compatibility with existing scripts