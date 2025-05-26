# Run script checks of the latest version of the packages in packages.json are installed, and installs them locally.
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

# Define file paths and variables
$envConfigPath = Join-Path -Path $(Get-ScriptRoot) -ChildPath "..\environments\dev.json"
$packagesJsonPath = Join-Path -Path $(Get-ScriptRoot) -ChildPath "packages.json"
$localPackagesDir = Join-Path -Path $(Get-ScriptRoot) -ChildPath "..\Packages"
$nugetPath = Join-Path -Path $(Get-ScriptRoot) -ChildPath "..\Tools\nuget.exe"

# Check if nuget.exe exists
if (-not (Test-Path $nugetPath)) {
    Write-Error "nuget.exe not found at $nugetPath. Please make sure it exists."
    exit 1
}

# Ensure local packages directory exists
if (-not (Test-Path $localPackagesDir)) {
    Write-Host "Creating local packages directory at $localPackagesDir"
    New-Item -ItemType Directory -Path $localPackagesDir -Force | Out-Null
}

# Load environment config
if (Test-Path $envConfigPath) {
    $envConfig = Get-Content -Path $envConfigPath -Raw | ConvertFrom-Json
    $KeyVaultName = $envConfig.keyVaultName
    $TenantId = $envConfig.tenantId
    $SubscriptionId = $envConfig.subscriptionId
    $ArtifactsFeedUrl = $envConfig.artifactsFeedUrl
    Write-Host "Using Key Vault: $KeyVaultName`nUsing Tenant ID: $TenantId`nUsing Subscription ID: $SubscriptionId`nUsing Artifacts Feed URL: $ArtifactsFeedUrl" -ForegroundColor Cyan
} else {
    Write-Error "Could not find environment config at $envConfigPath. Aborting script."
    exit 1
}

# Load packages list
if (Test-Path $packagesJsonPath) {
    $packagesList = @(Get-Content -Path $packagesJsonPath -Raw | ConvertFrom-Json)
    Write-Host "Found $(($packagesList | Measure-Object).Count) packages in packages.json" -ForegroundColor Cyan
} else {
    Write-Error "Could not find packages.json at $packagesJsonPath. Aborting script."
    exit 1
}

# Retrieve the PAT securely
try {
    Write-Host "Retrieving PAT from Key Vault..." -ForegroundColor Yellow
    $SecretName = "PAT" # Name of the secret storing the PAT
    $PersonalAccessToken = Get-PATFromKeyVault -KeyVaultName $KeyVaultName -SecretName $SecretName -TenantId $TenantId -SubscriptionId $SubscriptionId
    Write-Host "PAT retrieved successfully!" -ForegroundColor Green
} catch {
    Write-Error "Failed to retrieve PAT: $($_.Exception.Message)"
    exit 1
}

# Set up the NuGet source with the PAT
$nugetSourceName = "OrchestratorPsh"
try {
    Write-Host "Adding NuGet source..." -ForegroundColor Yellow
    # & $nugetPath source list 
    & $nugetPath sources add -Name $nugetSourceName -Source $ArtifactsFeedUrl -Username "AzureDevOps" -Password $PersonalAccessToken -StorePasswordInClearText
    Write-Host "NuGet source added successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to add NuGet source: $($_.Exception.Message)"
    exit 1
}

try {
    # Process each package in the list
    foreach ($packageName in $packagesList) {
        Write-Host "`nChecking package: $packageName" -ForegroundColor Cyan
        
        # Get the latest version from the feed (robust version handling)
        Write-Host "  Fetching latest version from feed..." -ForegroundColor Yellow
        $versionLines = & $nugetPath list $packageName -Source $nugetSourceName -AllVersions | Where-Object { $_ -match "^$packageName\s+\d+\.\d+\.\d+" }
        
        if (-not $versionLines) {
            Write-Warning "  Package $packageName not found in the feed. Skipping."
            continue
        }
        
        # Extract version numbers and sort them
        $versions = $versionLines | ForEach-Object { ($_ -split '\s+')[1] }
        $latestVersion = $versions | Sort-Object {[version]$_} -Descending | Select-Object -First 1
        Write-Host "  Latest version available: $latestVersion" -ForegroundColor Green
        
        # Check if the package is already installed
        $installedPackagePath = Join-Path -Path $localPackagesDir -ChildPath "$packageName.$latestVersion"
        $isInstalled = Test-Path $installedPackagePath
        
        if ($isInstalled) {
            Write-Host "  Package $packageName version $latestVersion is already installed." -ForegroundColor Green
        } else {
            # Install the package
            Write-Host "  Installing $packageName version $latestVersion..." -ForegroundColor Yellow
            & $nugetPath install $packageName -Version $latestVersion -Source $nugetSourceName -OutputDirectory $localPackagesDir -NoCache
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Package $packageName version $latestVersion installed successfully." -ForegroundColor Green
            } else {
                Write-Error "  Failed to install package $packageName version $latestVersion."
            }
        }
    }
} catch {
    Write-Error "Error processing packages: $($_.Exception.Message)"
} finally {
    # Clean up the NuGet source to remove sensitive information
    Write-Host "`nRemoving NuGet source..." -ForegroundColor Yellow
    & $nugetPath sources remove -Name $nugetSourceName
    Write-Host "NuGet source removed successfully." -ForegroundColor Green
}

Write-Host "`nPackage check and installation completed." -ForegroundColor Green
