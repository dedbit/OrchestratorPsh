# Script to test getting PAT from Key Vault and listing packages from Azure DevOps artifacts feed
# Import the Az module to interact with Azure services
# Import-Module Az

Import-Module ..\Modules\Configuration\ConfigurationPackage\ConfigurationPackage.psd1
Import-Module ..\Modules\OrchestratorAzure\OrchestratorAzure.psd1
Initialize-12Configuration ..\environments\dev.json
Connect-12Azure

# Determine script root in both script and console contexts
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

# Define Get-ScriptRoot function in case functions.ps1 import fails
function Get-ScriptRoot {
    if ($PSScriptRoot) { return $PSScriptRoot } 
    else { return (Get-Location).Path }
}

# Try to load shared functions
try {
    . "$ScriptRoot\functions.ps1"
    Write-Host "Functions loaded successfully." -ForegroundColor Green
} 
catch {
    Write-Warning "Could not load functions.ps1, using built-in Get-ScriptRoot function."
}

# Import OrchestratorCommon module
$moduleRoot = Join-Path -Path $ScriptRoot -ChildPath "..\Modules\OrchestratorCommon"
if (Test-Path $moduleRoot) {
    Import-Module $moduleRoot -Force
    Write-Host "OrchestratorCommon module imported successfully." -ForegroundColor Green
} else {
    Write-Error "OrchestratorCommon module not found at $moduleRoot. Make sure the module is installed correctly."
    exit 1
}

# Define variables
$envConfigPath = Join-Path -Path $ScriptRoot -ChildPath "..\environments\dev.json"
if (Test-Path $envConfigPath) {    $envConfig = Get-Content -Path $envConfigPath -Raw | ConvertFrom-Json
    $KeyVaultName = $envConfig.keyVaultName
    $TenantId = $envConfig.tenantId
    $SubscriptionId = $envConfig.subscriptionId
    $ArtifactsFeedUrl = $envConfig.artifactsFeedUrl
    Write-Host "Using Key Vault: $KeyVaultName from environments/dev.json" -ForegroundColor Cyan
    Write-Host "Using Tenant ID: $TenantId from environments/dev.json" -ForegroundColor Cyan
    Write-Host "Using Subscription ID: $SubscriptionId from environments/dev.json" -ForegroundColor Cyan
    Write-Host "Using Artifacts Feed URL: $ArtifactsFeedUrl from environments/dev.json" -ForegroundColor Cyan
} else {
    Write-Error "Could not find environment config at $envConfigPath. Aborting script."
    exit 1
}

$SecretName = "PAT"   # Name of the secret storing the PAT

# Retrieve the PAT securely
try {
    Write-Host "Retrieving PAT from Key Vault..." -ForegroundColor Yellow
    $PersonalAccessToken = Get-PATFromKeyVault -KeyVaultName $KeyVaultName -SecretName $SecretName -TenantId $TenantId -SubscriptionId $SubscriptionId
    Write-Host "PAT retrieved successfully!" -ForegroundColor Green
} catch {
    Write-Error "Failed to retrieve PAT: $($_.Exception.Message)"
    exit 1
}

# Check if nuget.exe exists
$nugetPath = Join-Path -Path $ScriptRoot -ChildPath "..\Tools\nuget.exe"
if (-not (Test-Path $nugetPath)) {
    Write-Error "nuget.exe not found at $nugetPath. Please make sure it exists."
    exit 1
}

# Clean up any existing source with the same name
$existingSources = & $nugetPath sources list | Select-String "ArtifactsFeed"
if ($existingSources) {
    Write-Host "Removing existing ArtifactsFeed source..." -ForegroundColor Yellow
    & $nugetPath sources remove -Name "ArtifactsFeed" | Out-Null
}

Write-Host "Adding NuGet source..." -ForegroundColor Yellow
# Add the source with -NonInteractive to avoid prompts
$sourceAddOutput = & $nugetPath sources add -Name "ArtifactsFeed" -Source $ArtifactsFeedUrl -Username "AzureDevOps" -Password $PersonalAccessToken -StorePasswordInClearText -NonInteractive 2>&1
if ($LASTEXITCODE -ne 0) {
    # Even if exit code indicates failure, it might still work if the error is just "already exists"
    if ($sourceAddOutput -match "already been added") {
        Write-Host "NuGet source already exists and can be used." -ForegroundColor Green
    } else {
        Write-Warning "Error adding NuGet source: $sourceAddOutput"
    }
} else {
    Write-Host "NuGet source added successfully." -ForegroundColor Green
}

# List packages from the feed - use direct URL instead of source name
Write-Host "Listing packages from the artifacts feed..." -ForegroundColor Yellow
$result = & $nugetPath search -Source $ArtifactsFeedUrl -PreRelease -Verbosity detailed -NonInteractive
if ($LASTEXITCODE -ne 0) {
    Write-Warning "NuGet search returned with error code $LASTEXITCODE"
    Write-Warning "Output: $result"
} else {
    Write-Host "Packages listed successfully." -ForegroundColor Green
}

# Clean up the NuGet source to remove sensitive information
Write-Host "Removing NuGet source..." -ForegroundColor Yellow
$existingSources = & $nugetPath sources list | Select-String "ArtifactsFeed"
if ($existingSources) {
    & $nugetPath sources remove -Name "ArtifactsFeed" | Out-Null
    Write-Host "NuGet source removed successfully." -ForegroundColor Green
} else {
    Write-Host "NuGet source not found for removal." -ForegroundColor Cyan
}

Write-Host "Test completed successfully!" -ForegroundColor Green
