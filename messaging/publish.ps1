# publish.ps1
# Script to publish the messaging package to a NuGet feed

# Import the Az module to interact with Azure services
# Import-Module Az

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
    $ArtifactsFeedUrl = $envConfig.artifactsFeedUrl
    Write-Host "Using Key Vault: $KeyVaultName from environments/dev.json`nUsing Tenant ID: $TenantId from environments/dev.json`nUsing Subscription ID: $SubscriptionId from environments/dev.json`nUsing Artifacts Feed URL: $ArtifactsFeedUrl from environments/dev.json" -ForegroundColor Cyan
} else {
    Write-Error "Could not find environment config at $envConfigPath. Aborting package publishing."
    exit 1
}

# Get the package version from the nuspec file
$packagePath = "MessagingPackage.nuspec"
$nuspecContent = Get-Content $packagePath -Raw
if ($nuspecContent -match '<version>([0-9]+)\.([0-9]+)\.([0-9]+)</version>') {
    $major = $matches[1]
    $minor = $matches[2]
    $patch = $matches[3]
    $version = "$major.$minor.$patch"
    Write-Host "Package version from nuspec: $version" -ForegroundColor Cyan
} else {
    Write-Error "Failed to find version in nuspec file."
    exit 1
}

# Detect the latest package in the output directory
$outputDirectory = "..\Output"
$PackagePath = Join-Path -Path $outputDirectory -ChildPath "MessagingPackage.$version.nupkg"
Write-Host "Using package path: $PackagePath" -ForegroundColor Cyan

$SecretName = "PAT"   # Replace with the name of the secret storing the PAT

# Verify the package exists
if (-not (Test-Path $PackagePath)) {
    Write-Error "Package not found at $PackagePath. Please build the package first."
    exit 1
}

Write-Host "Publishing package $PackagePath..." -ForegroundColor Cyan

# Retrieve the PAT securely
$PersonalAccessToken = Get-PATFromKeyVault -KeyVaultName $KeyVaultName -SecretName $SecretName -TenantId $TenantId -SubscriptionId $SubscriptionId

# Set the NuGet source name
$ArtifactsFeed = "OrchestratorPsh"

# Set up the NuGet source with the PAT
Write-Host "Adding NuGet source..." -ForegroundColor Cyan
nuget sources add -Name $ArtifactsFeed -Source $ArtifactsFeedUrl -Username "AzureDevOps" -Password $PersonalAccessToken -StorePasswordInClearText

# Publish the package
Write-Host "Pushing package to feed..." -ForegroundColor Cyan
nuget push $PackagePath -Source $ArtifactsFeed -ApiKey "AzureDevOps"

# Clean up the NuGet source to remove sensitive information
Write-Host "Cleaning up..." -ForegroundColor Cyan
nuget sources remove -Name $ArtifactsFeed

Write-Host "Package published successfully!" -ForegroundColor Green
