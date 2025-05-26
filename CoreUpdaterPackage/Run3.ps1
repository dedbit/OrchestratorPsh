# Run script checks of the latest version of the packages in packages.json are installed, and installs them locally.
# This script is like Run.ps1, but is being setup to use PSRepository for installing packages. 
# Todo
# Certificate based authentication to Artifacts feed
# Move ensuring repository to a function

# Import the Az module to interact with Azure services
# Import-Module Az

. .\functions.ps1

Import-Module ..\Modules\Configuration\ConfigurationPackage.psd1
Import-Module ..\Modules\OrchestratorAzure\OrchestratorAzure.psd1
Initialize-12Configuration
Connect-12Azure

# Import OrchestratorCommon module
$moduleRoot = Join-Path -Path $(Get-ScriptRoot) -ChildPath "..\Modules\OrchestratorCommon"
if (Test-Path $moduleRoot) {
    Import-Module $moduleRoot -Force
    Write-Host "OrchestratorCommon module imported successfully." -ForegroundColor Green
} else {
    Write-Error "OrchestratorCommon module not found at $moduleRoot. Make sure the module is installed correctly."
    exit 1
}

# Load environment config
$envConfigPath = Join-Path -Path $(Get-ScriptRoot) -ChildPath "..\environments\dev.json"
if (Test-Path $envConfigPath) {
    $envConfig = Get-Content -Path $envConfigPath -Raw | ConvertFrom-Json
    $ArtifactsFeedUrlV2 = $envConfig.artifactsFeedUrlV2
} else {
    Write-Error "Could not find environment config at $envConfigPath. Aborting script."
    exit 1
}

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

try {
    foreach ($packageName in $packagesList) {
        Write-Host "\nChecking package: $packageName" -ForegroundColor Cyan
        $installed = Get-InstalledModule -Name $packageName -ErrorAction SilentlyContinue
        $repoModules = Find-Module -Name $packageName -Repository $repoName -ErrorAction SilentlyContinue
        if ($repoModules) {
            $latestVersion = $repoModules.Version
            if ($installed) {
                if ([version]$installed.Version -lt [version]$latestVersion) {
                    Write-Host "  Newer version $latestVersion available. Upgrading $packageName..." -ForegroundColor Yellow
                    Uninstall-Module -Name $packageName -AllVersions -Force
                    Install-Module -Name $packageName -Repository $repoName -RequiredVersion $latestVersion -Force -Scope AllUsers
                    $installed2 = Get-InstalledModule -Name $packageName -ErrorAction SilentlyContinue
                    if ($installed2 -and $installed2.Version -eq $latestVersion) {
                        Write-Host "  Package $packageName upgraded to version $($installed2.Version)." -ForegroundColor Green
                    } else {
                        Write-Error "  Failed to upgrade $packageName to $latestVersion."
                    }
                } else {
                    Write-Host "  Package $packageName is up to date (version $($installed.Version))." -ForegroundColor Green
                }
            } else {
                Write-Host "  Installing $packageName version $latestVersion from $repoName..." -ForegroundColor Yellow
                Install-Module -Name $packageName -Repository $repoName -RequiredVersion $latestVersion -Force -Scope AllUsers
                $installed2 = Get-InstalledModule -Name $packageName -ErrorAction SilentlyContinue
                if ($installed2 -and $installed2.Version -eq $latestVersion) {
                    Write-Host "  Package $packageName version $($installed2.Version) installed successfully." -ForegroundColor Green
                } else {
                    Write-Error "  Failed to install package $packageName version $latestVersion from $repoName."
                }
            }
        } else {
            Write-Warning "  Package $packageName not found in repository $repoName. Skipping."
        }
    }
} catch {
    Write-Error "Error processing packages: $($_.Exception.Message)"
}

Write-Host "\nPackage check and installation completed." -ForegroundColor Green
