# Run script checks of the latest version of the packages in packages.json are installed, and installs them locally.
# This script is like Run.ps1, but is being setup to use PSRepository for installing packages. 
# Todo
# Certificate based authentication to Artifacts feed
# Move ensuring repository to a function

# Import the Az module to interact with Azure services
# Import-Module Az

. "$PSScriptRoot\functions.ps1"

# Import the Configuration module from the correct subfolder
Import-Module "$PSScriptRoot\..\Modules\Configuration\ConfigurationPackage\ConfigurationPackage.psd1" -Force
Import-Module "$PSScriptRoot\..\Modules\OrchestratorAzure\OrchestratorAzure.psd1" -Force

# Initialize-12Configuration should be called with the path to dev.json
$envConfigPath = Join-Path -Path $PSScriptRoot -ChildPath "..\environments\dev.json"
Initialize-12Configuration $envConfigPath
Connect-12Azure

# Import OrchestratorCommon module
$moduleRoot = Join-Path -Path $PSScriptRoot -ChildPath "..\Modules\OrchestratorCommon"
if (Test-Path $moduleRoot) {
    Import-Module $moduleRoot -Force
    Write-Host "OrchestratorCommon module imported successfully." -ForegroundColor Green
} else {
    Write-Error "OrchestratorCommon module not found at $moduleRoot. Make sure the module is installed correctly."
    exit 1
}

# Use loaded configuration from $global:12cConfig instead of loading dev.json manually
$ArtifactsFeedUrlV2 = $global:12cConfig.artifactsFeedUrlV2

# Ensure PSRepository is set up
Ensure-12PsRepository
$repoName = 'OrchestratorPshRepo22'

# Load packages list
$packagesJsonPath = Join-Path -Path $(Get-ScriptRoot) -ChildPath "packages.json"
if (Test-Path $packagesJsonPath) {
    $packagesList = @(Get-Content -Path $packagesJsonPath -Raw | ConvertFrom-Json)
    Write-Host "Found $(($packagesList | Measure-Object).Count) packages in packages.json" -ForegroundColor Cyan
} else {
    Write-Error "Could not find packages.json at $packagesJsonPath. Aborting script."
    exit 1
}

# Check for administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "You are NOT running this script as Administrator. Some operations (like -Scope AllUsers) require admin rights. Aborting script."
    exit 1
}

# Main logic: For each package in the list, check if it is installed and if the latest version is available in the repository.
# - If installed and out of date, uninstall and upgrade to the latest version from the repository.
# - If installed and up to date, skip.
# - If not installed, install the latest version from the repository.
# - If the package is not found in the repository, skip and warn.
# Error handling ensures any issues are reported and the script continues to the next package.
try {
    foreach ($packageName in $packagesList) {
        Write-Host "\nChecking package: $packageName" -ForegroundColor Cyan
        $installed = Get-InstalledModule -Name $packageName -ErrorAction SilentlyContinue
        $loadedInSession = Get-Module -Name $packageName | Sort-Object Version -Descending | Select-Object -First 1
        $repoModules = Find-Module -Name $packageName -Repository $repoName -ErrorAction SilentlyContinue
        if ($repoModules) {
            $latestVersion = $repoModules.Version
            $loadedVersion = $null
            if ($loadedInSession) {
                $loadedVersion = $loadedInSession.Version
                if ([version]$loadedVersion -eq [version]$latestVersion) {
                    Write-Host "  Module $packageName version $loadedVersion is already loaded and up to date. Skipping update." -ForegroundColor Green
                    continue
                } else {
                    Write-Host "  Loaded version $loadedVersion is older than latest $latestVersion. Will update." -ForegroundColor Yellow
                }
            } elseif ($installed) {
                Write-Host "  Module $packageName is installed but not loaded in session." -ForegroundColor Yellow
            } else {
                Write-Host "  Module $packageName is not installed or loaded. Will install latest version $latestVersion." -ForegroundColor Yellow
            }
            # Uninstall all older versions before installing latest
            if ($installed) {
                $olderVersions = Get-InstalledModule -Name $packageName -AllVersions | Where-Object { [version]$_.Version -lt [version]$latestVersion }
                foreach ($old in $olderVersions) {
                    Write-Host "  Removing old version $($old.Version) of $packageName..." -ForegroundColor Yellow
                    Uninstall-Module -Name $packageName -RequiredVersion $old.Version -Force
                }
            }
            # Install or update to latest version
            Install-Module -Name $packageName -Repository $repoName -RequiredVersion $latestVersion -Force -Scope AllUsers
            $installed2 = Get-InstalledModule -Name $packageName -ErrorAction SilentlyContinue
            if ($installed2 -and $installed2.Version -eq $latestVersion) {
                Write-Host "  Package $packageName version $($installed2.Version) installed/updated successfully." -ForegroundColor Green
                # Remove all versions older than the loaded/updated version
                $allVersions = Get-InstalledModule -Name $packageName -AllVersions | Where-Object { [version]$_.Version -lt [version]$latestVersion }
                foreach ($old in $allVersions) {
                    Write-Host "  Removing old version $($old.Version) of $packageName after update..." -ForegroundColor Yellow
                    Uninstall-Module -Name $packageName -RequiredVersion $old.Version -Force
                }
            } else {
                Write-Error "  Failed to install/update package $packageName version $latestVersion from $repoName."
            }
        } else {
            Write-Warning "  Package $packageName not found in repository $repoName. Skipping."
        }
    }
} catch {
    Write-Error "Error processing packages: $($_.Exception.Message)"
}

Write-Host "\nPackage check and installation completed." -ForegroundColor Green
