# ConfigurationPackage Module

A PowerShell module for managing configuration in the OrchestratorPsh ecosystem.

For detailed architecture information, see [Architecture.md](./Architecture.md).

## Installation Options

### Option 1: Install from local NuGet feed (recommended)

```powershell
# Register local NuGet repository (run once)
Register-PSRepository -Name LocalNuget -SourceLocation "C:\dev\12C\OrchestratorPsh\Output" -InstallationPolicy Trusted

# Install the Configuration package for all users
Install-Module -Name ConfigurationPackage -Scope AllUsers -Repository LocalNuget -Force
```

### Option 2: Import directly from source (for development)

```powershell
# Import the module directly from source
Import-Module -Path "C:\dev\12C\OrchestratorPsh\Modules\Configuration\ConfigurationPackage\ConfigurationPackage.psd1" -Force
```

### Option 3: Manually copy to system modules folder

```powershell
# Copy to PowerShell modules directory
Copy-Item -Recurse -Force "C:\dev\12C\OrchestratorPsh\Modules\Configuration" "C:\Program Files\PowerShell\Modules\ConfigurationPackage"
```

## Usage

```powershell
# Import the module (if not already imported)
Import-Module -Name ConfigurationPackage

# Get all commands in the module
Get-Command -Module ConfigurationPackage

# Use functions from the module
Initialize-12Configuration
$commandPath = Get-PSCommandPath
```

## Managing Package Versions

```powershell
# Find available module versions
Find-Module -Name ConfigurationPackage -Repository LocalNuget

# Update to the latest version
Update-Module -Name ConfigurationPackage -Force

# Remove and reimport the module after updates
Remove-Module -Name ConfigurationPackage -ErrorAction SilentlyContinue
Import-Module -Name ConfigurationPackage
```
