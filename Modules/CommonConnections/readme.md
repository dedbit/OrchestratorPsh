# CommonConnectionsPackage Module

A PowerShell module for managing connection details in the OrchestratorPsh ecosystem.

For detailed architecture information, see [Architecture.md](./Architecture.md).

## Installation Options

### Option 1: Install from local NuGet feed (recommended)

```powershell
# Register local NuGet repository (run once)
Register-PSRepository -Name LocalNuget -SourceLocation "C:\dev\12C\OrchestratorPsh\Output" -InstallationPolicy Trusted

# Install the CommonConnections package for all users
Install-Module -Name CommonConnectionsPackage -Scope AllUsers -Repository LocalNuget -Force
```

### Option 2: Import directly from source (for development)

```powershell
# Import the module directly from source
Import-Module -Path "C:\dev\12C\OrchestratorPsh\Modules\CommonConnections\CommonConnectionsPackage\CommonConnectionsPackage.psd1" -Force
```

### Option 3: Manually copy to system modules folder

```powershell
# Copy to PowerShell modules directory
Copy-Item -Recurse -Force "C:\dev\12C\OrchestratorPsh\Modules\CommonConnections" "C:\Program Files\PowerShell\Modules\CommonConnectionsPackage"
```

## Usage

```powershell
# Import the module (if not already imported)
Import-Module -Name CommonConnectionsPackage

# Get all connection details
$allConnections = Get-12cConnection

# Get specific connection property
$tenantId = Get-12cConnection -ConnectionName 'tenantId'
$keyVaultName = Get-12cConnection -ConnectionName 'keyVaultName'
$artifactsFeedUrl = Get-12cConnection -ConnectionName 'artifactsFeedUrl'

# Use custom configuration file
$connections = Get-12cConnection -ConfigFilePathOverride "C:\path\to\custom\config.json"
```

## Available Connection Properties

The module provides access to all connection details from the JSON configuration:

- **Azure Properties**: `tenantId`, `subscriptionId`, `keyVaultName`, `resourceGroupName`, `appId`, `appObjectId`
- **Certificate Properties**: `certName`, `certThumbprint`, `expiryYears`
- **DevOps Properties**: `artifactsFeedUrl`, `artifactsFeedUrlV2`
- **General Properties**: `location`, `appName`, `storageAccountName`

## Managing Package Versions

```powershell
# Find available module versions
Find-Module -Name CommonConnectionsPackage -Repository LocalNuget

# Update to the latest version
Update-Module -Name CommonConnectionsPackage -Force

# Remove and reimport the module after updates
Remove-Module -Name CommonConnectionsPackage -ErrorAction SilentlyContinue
Import-Module -Name CommonConnectionsPackage
```

## Future Migration Support

The module is designed with flexibility in mind to support future migration to Azure App Configuration:

- JSON parsing capabilities can be extended to support nested configurations
- Connection property access supports both flat and hierarchical structures
- Configuration caching mechanism can be adapted for Azure App Configuration refresh patterns
- Error handling and fallback mechanisms are already in place