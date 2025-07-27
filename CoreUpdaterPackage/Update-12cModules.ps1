# Run script checks of the latest version of the packages in packages.json are installed, and installs them locally.
# This script is self-contained and does not depend on external modules.
# It uses certificate-based authentication to Azure and Artifacts feed.

# Define paths at top of script
$functionsPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'Functions\functions.ps1'
$configPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'config.json'

. $functionsPath

# Initialize configuration from local config file
Initialize-12Configuration $configPath
Connect-12AzureWithCertificate

# Ensure NuGet provider is properly installed and configured
Ensure-NuGetProvider

# Ensure PSRepository is set up
Ensure-12PsRepository
$repoName = 'OrchestratorPshRepo22'

# Load packages list - try KeyVault first, fallback to local file
$packagesList = $null

# Try to get packages from KeyVault first
try {
    Write-Host "Attempting to retrieve packages list from Key Vault..." -ForegroundColor Cyan
    $secretValueText = Get-12cKeyVaultSecret -SecretName "Packages"
    $packagesList = @($secretValueText | ConvertFrom-Json)
    Write-Host "✓ Successfully loaded packages from Key Vault" -ForegroundColor Green
} catch {
    Write-Warning "Failed to retrieve packages from Key Vault: $($_.Exception.Message)"
    Write-Host "Falling back to local packages.json file..." -ForegroundColor Yellow
}

# Fallback to local packages.json if KeyVault failed or not configured
if (-not $packagesList) {
    $packagesJsonPath = Join-Path -Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) -ChildPath "packages.json"
    if (Test-Path $packagesJsonPath) {
        $packagesList = @(Get-Content -Path $packagesJsonPath -Raw | ConvertFrom-Json)
        Write-Host "Found $(($packagesList | Measure-Object).Count) packages in local packages.json" -ForegroundColor Cyan
    } else {
        Write-Error "Could not find packages.json at $packagesJsonPath and failed to retrieve from Key Vault. Aborting script."
        exit 1
    }
}

# Validate we have packages
if (-not $packagesList -or $packagesList.Count -eq 0) {
    Write-Error "No packages found in either Key Vault or local packages.json. Aborting script."
    exit 1
}

Write-Host "Total packages to process: $(($packagesList | Measure-Object).Count)" -ForegroundColor Green

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
        # $packageName = $packagesList[0]
        Write-Host "Checking package: $packageName" -ForegroundColor Cyan
        $installed = Get-InstalledModule -Name $packageName -ErrorAction SilentlyContinue
        $loadedInSession = Get-Module -Name $packageName | Sort-Object Version -Descending | Select-Object -First 1
        
        try {
            if ($global:12cPSRepositoryCredential) {
                $repoModules = Find-Module -Name $packageName -Repository $repoName -Credential $global:12cPSRepositoryCredential -ErrorAction Stop
            }
            else {
                $repoModules = Find-Module -Name $packageName -Repository $repoName -ErrorAction Stop
            }
        }
        catch {
            Write-Host "  Failed to find package $packageName in repository $repoName. Error: $($_.Exception.Message)`n  Troubleshooting tips:`n    - Verify the package name is correct`n    - Check if the package is published to the repository`n    - Verify repository access with: Find-Module -Repository $repoName" -ForegroundColor Yellow
            continue
        }
        if (-not $repoModules) {
            # Removed irrelevant warning message
            continue
        }

        $latestVersion = $repoModules.Version
        if ($loadedInSession) {
            $loadedVersion = $loadedInSession.Version
            if ([version]$loadedVersion -eq [version]$latestVersion) {
                Write-Host "  Module $packageName version $loadedVersion is already loaded and up to date. Skipping update." -ForegroundColor Green
                continue
            }
            Write-Host "  Loaded version $loadedVersion is older than latest $latestVersion. Will update." -ForegroundColor Yellow
        }
        elseif ($installed) {
            if ([version]$installed.Version -eq [version]$latestVersion) {
                Write-Host "  Module $packageName is installed but not loaded in session, and is up to date. Skipping update." -ForegroundColor Green
                continue
            }
            Write-Host "  Module $packageName is installed but not loaded in session. Installed version $($installed.Version) is older than latest $latestVersion. Will update." -ForegroundColor Yellow
        }
        else {
            Write-Host "  Module $packageName is not installed or loaded. Will install latest version $latestVersion." -ForegroundColor Yellow
            # Uninstall all older versions before installing latest
            if ($installed -and [version]$installed.Version -ne [version]$latestVersion) {
                $olderVersions = Get-InstalledModule -Name $packageName -AllVersions | Where-Object { [version]$_.Version -lt [version]$latestVersion }
                foreach ($old in $olderVersions) {
                    Write-Host "  Removing old version $($old.Version) of $packageName..." -ForegroundColor Yellow
                    Uninstall-Module -Name $packageName -RequiredVersion $old.Version -Force
                }
            }
        }
        # Install or update to latest version
        Write-Host "  Installing/updating $packageName version $latestVersion..." -ForegroundColor Cyan
        try {
            if ($global:12cPSRepositoryCredential) {
                Install-Module -Name $packageName -Repository $repoName -RequiredVersion $latestVersion -Force -Scope AllUsers -Credential $global:12cPSRepositoryCredential
            }
            else {
                Install-Module -Name $packageName -Repository $repoName -RequiredVersion $latestVersion -Force -Scope AllUsers
            }
        }
        catch {
            Write-Error "  Failed to install/update package $packageName version $latestVersion from $repoName. Error: $($_.Exception.Message)"
            continue
        }
        $installed2 = Get-InstalledModule -Name $packageName -ErrorAction SilentlyContinue
        if ($installed2 -and $installed2.Version -eq $latestVersion) {
            Write-Host "  Package $packageName version $($installed2.Version) installed/updated successfully." -ForegroundColor Green
            # Remove all versions older than the loaded/updated version
            # Skip redundant redefinition of $allVersions inside the loop
            foreach ($old in $allVersions) {
                Write-Host "  Removing old version $($old.Version) of $packageName after update..." -ForegroundColor Yellow
                # Remove all versions older than the loaded/updated version if not actively in use
                $allVersions = Get-InstalledModule -Name $packageName -AllVersions | Where-Object { [version]$_.Version -lt [version]$latestVersion }
                foreach ($old in $allVersions) {
                    $isInUse = Get-Module -Name $packageName | Where-Object { $_.Version -eq $old.Version }
                    if (-not $isInUse) {
                        Write-Host "  Removing non-active version $($old.Version) of $packageName..." -ForegroundColor Yellow
                        Uninstall-Module -Name $packageName -RequiredVersion $old.Version -Force
                    }
                    else {
                        Write-Warning "  Package $packageName not found in repository $repoName. Skipping."
                        Write-Host "  Troubleshooting tips:" -ForegroundColor Yellow
                        Write-Host "    - Verify the package name is correct." -ForegroundColor Yellow
                        Write-Host "    - Check if the package is published to the repository." -ForegroundColor Yellow
                        Write-Host "    - Verify repository access with: Find-Module -Repository $repoName" -ForegroundColor Yellow
                    }
                    Write-Host "  Skipping removal of version $($old.Version) because it is actively loaded in the current session and cannot be removed." -ForegroundColor Cyan
                }
            }
            Write-Warning "  Package $packageName not found in repository $repoName. Skipping."
        }
    }
}
catch {
    Write-Error "Error processing packages: $($_.Exception.Message)"
}

Write-Host "Package check and installation completed." -ForegroundColor Green
