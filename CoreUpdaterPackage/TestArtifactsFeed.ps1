# Script to test getting PAT from Key Vault and listing packages from Azure DevOps artifacts feed
# Import the Az module to interact with Azure services
Import-Module Az

# Import OrchestratorCommon module
$moduleRoot = Join-Path -Path $PSScriptRoot -ChildPath "..\Modules\OrchestratorCommon"
if (Test-Path $moduleRoot) {
    Import-Module $moduleRoot -Force
    Write-Host "OrchestratorCommon module imported successfully." -ForegroundColor Green
} else {
    Write-Error "OrchestratorCommon module not found at $moduleRoot. Make sure the module is installed correctly."
    exit 1
}

# Define variables
$envConfigPath = Join-Path -Path $PSScriptRoot -ChildPath "..\environments\dev.json"
if (Test-Path $envConfigPath) {
    $envConfig = Get-Content -Path $envConfigPath -Raw | ConvertFrom-Json
    $KeyVaultName = $envConfig.keyVaultName
    $TenantId = $envConfig.tenantId
    $SubscriptionId = $envConfig.subscriptionId
    Write-Host "Using Key Vault: $KeyVaultName from environments/dev.json" -ForegroundColor Cyan
    Write-Host "Using Tenant ID: $TenantId from environments/dev.json" -ForegroundColor Cyan
    Write-Host "Using Subscription ID: $SubscriptionId from environments/dev.json" -ForegroundColor Cyan
} else {
    Write-Error "Could not find environment config at $envConfigPath. Aborting script."
    exit 1
}

$SecretName = "PAT"   # Name of the secret storing the PAT
$ArtifactsFeedUrl = "https://pkgs.dev.azure.com/12c/_packaging/Common/nuget/v3/index.json"  # Your feed URL

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
$nugetPath = Join-Path -Path $PSScriptRoot -ChildPath "..\Tools\nuget.exe"
if (-not (Test-Path $nugetPath)) {
    Write-Error "nuget.exe not found at $nugetPath. Please make sure it exists."
    exit 1
}

# Set up the NuGet source with the PAT
try {
    Write-Host "Adding NuGet source..." -ForegroundColor Yellow
    & $nugetPath sources add -Name "ArtifactsFeed" -Source $ArtifactsFeedUrl -Username "AzureDevOps" -Password $PersonalAccessToken -StorePasswordInClearText
    Write-Host "NuGet source added successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to add NuGet source: $($_.Exception.Message)"
    # Clean up before exiting
    & $nugetPath sources remove -Name "ArtifactsFeed" -ErrorAction SilentlyContinue
    exit 1
}

try {
    # List packages from the feed
    Write-Host "Listing packages from the artifacts feed..." -ForegroundColor Yellow
    & $nugetPath list -Source "ArtifactsFeed" -AllVersions
    Write-Host "Packages listed successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to list packages: $($_.Exception.Message)"
} finally {
    # Clean up the NuGet source to remove sensitive information
    Write-Host "Removing NuGet source..." -ForegroundColor Yellow
    & $nugetPath sources remove -Name "ArtifactsFeed"
    Write-Host "NuGet source removed successfully." -ForegroundColor Green
}

Write-Host "Test completed successfully!" -ForegroundColor Green
