# Define paths at top of script
$scriptRoot = $PSScriptRoot ? $PSScriptRoot : (Get-Location).Path
$moduleRoot = Join-Path $scriptRoot '..\Modules\OrchestratorCommon'
$envConfigPath = Join-Path $scriptRoot '..\environments\dev.json'

# Import the Az module to interact with Azure services
# Import-Module Az

# Import OrchestratorCommon module
if (Test-Path $moduleRoot) {
    Import-Module $moduleRoot -Force
    Write-Host "OrchestratorCommon module imported successfully." -ForegroundColor Green
} else {
    Write-Error "OrchestratorCommon module not found at $moduleRoot. Make sure the module is installed correctly."
    exit 1
}

# Define variables
if (Test-Path $envConfigPath) {
    $envConfig = Get-Content -Path $envConfigPath -Raw | ConvertFrom-Json
    $KeyVaultName = $envConfig.keyVaultName
    $TenantId = $envConfig.tenantId
    $SubscriptionId = $envConfig.subscriptionId
    $ArtifactsFeedUrl = $envConfig.artifactsFeedUrl
    Write-Host "Using Key Vault: $KeyVaultName from environments/dev.json" -ForegroundColor Cyan
    Write-Host "Using Tenant ID: $TenantId from environments/dev.json" -ForegroundColor Cyan
    Write-Host "Using Subscription ID: $SubscriptionId from environments/dev.json" -ForegroundColor Cyan
    Write-Host "Using Artifacts Feed URL: $ArtifactsFeedUrl from environments/dev.json" -ForegroundColor Cyan
} else {
    Write-Error "Could not find environment config at $envConfigPath. Aborting package publishing."
    exit 1
}

$SecretName = "PAT"   # Replace with the name of the secret storing the PAT

# Detect the latest package in the correct output directory
$outputDirectory = Join-Path $scriptRoot '..' 'Output'
$packageFiles = Get-ChildItem -Path $outputDirectory -Filter 'CoreUpdaterPackage.*.nupkg' | Sort-Object Name -Descending
if ($packageFiles) {
    $PackagePath = $packageFiles[0].FullName
    Write-Host "Using latest package: $PackagePath" -ForegroundColor Cyan
} else {
    Write-Error "No CoreUpdaterPackage nupkg files found in $outputDirectory."
    exit 1
}

# Retrieve the PAT securely
$PersonalAccessToken = Get-PATFromKeyVault -KeyVaultName $KeyVaultName -SecretName $SecretName -TenantId $TenantId -SubscriptionId $SubscriptionId

# Set up the NuGet source with the PAT
nuget.exe sources add -Name "ArtifactsFeed" -Source $ArtifactsFeedUrl -Username "AzureDevOps" -Password $PersonalAccessToken -StorePasswordInClearText

# Publish the package
nuget.exe push $PackagePath -Source "ArtifactsFeed" -ApiKey "AzureDevOps"

# Clean up the NuGet source to remove sensitive information
nuget.exe sources remove -Name "ArtifactsFeed"