# publish.ps1
# Script to publish the messaging package to a NuGet feed

# Import the Az module to interact with Azure services
Import-Module Az

# Function to retrieve the Personal Access Token (PAT) from Azure Key Vault
function Get-PATFromKeyVault {
    param (
        [string]$KeyVaultName,
        [string]$SecretName,
        [string]$TenantId,
        [string]$SubscriptionId
    )

    # Login to Azure with tenant and subscription (if not already logged in)
    Connect-AzAccount -TenantId $TenantId -SubscriptionId $SubscriptionId -ErrorAction Stop

    # Retrieve the secret from Azure Key Vault
    $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -ErrorAction Stop
    return $secret.SecretValueText
}

# Parameters
param (
    [string]$PackagePath = "..\Output\MessagingPackage.1.0.0.nupkg",
    [string]$Version = "1.0.0"
)

# Define variables
$envConfigPath = "..\environments\dev.json"
if (Test-Path $envConfigPath) {
    $envConfig = Get-Content -Path $envConfigPath -Raw | ConvertFrom-Json
    $KeyVaultName = $envConfig.keyVaultName
    $TenantId = $envConfig.tenantId
    $SubscriptionId = $envConfig.subscriptionId
    Write-Host "Using Key Vault: $KeyVaultName from environments/dev.json" -ForegroundColor Cyan
    Write-Host "Using Tenant ID: $TenantId from environments/dev.json" -ForegroundColor Cyan
    Write-Host "Using Subscription ID: $SubscriptionId from environments/dev.json" -ForegroundColor Cyan
} else {
    Write-Error "Could not find environment config at $envConfigPath. Aborting package publishing."
    exit 1
}

# If package path is the default, but version is specified, update the path
if ($PackagePath -eq "..\Output\MessagingPackage.1.0.0.nupkg" -and $Version -ne "1.0.0") {
    $PackagePath = "..\Output\MessagingPackage.$Version.nupkg"
    Write-Host "Updated package path to: $PackagePath" -ForegroundColor Yellow
}

$SecretName = "PAT"   # Replace with the name of the secret storing the PAT
$ArtifactsFeedUrl = "https://pkgs.dev.azure.com/12c/_packaging/Common/nuget/v3/index.json"  # Replace with your feed URL

# Verify the package exists
if (-not (Test-Path $PackagePath)) {
    Write-Error "Package not found at $PackagePath. Please build the package first."
    exit 1
}

Write-Host "Publishing package $PackagePath..." -ForegroundColor Cyan

# Retrieve the PAT securely
$PersonalAccessToken = Get-PATFromKeyVault -KeyVaultName $KeyVaultName -SecretName $SecretName -TenantId $TenantId -SubscriptionId $SubscriptionId

# Set up the NuGet source with the PAT
Write-Host "Adding NuGet source..." -ForegroundColor Cyan
nuget sources add -Name "ArtifactsFeed" -Source $ArtifactsFeedUrl -Username "AzureDevOps" -Password $PersonalAccessToken -StorePasswordInClearText

# Publish the package
Write-Host "Pushing package to feed..." -ForegroundColor Cyan
nuget push $PackagePath -Source "ArtifactsFeed" -ApiKey "AzureDevOps"

# Clean up the NuGet source to remove sensitive information
Write-Host "Cleaning up..." -ForegroundColor Cyan
nuget sources remove -Name "ArtifactsFeed"

Write-Host "Package published successfully!" -ForegroundColor Green
