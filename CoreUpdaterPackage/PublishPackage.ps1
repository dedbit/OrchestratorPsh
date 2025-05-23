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

    # Check if already connected to Azure
    $context = Get-AzContext
    if (-not $context -or $context.Tenant.Id -ne $TenantId -or $context.Subscription.Id -ne $SubscriptionId) {
        Write-Host "Connecting to Azure with Tenant ID: $TenantId and Subscription ID: $SubscriptionId" -ForegroundColor Cyan
        Connect-AzAccount -TenantId $TenantId -SubscriptionId $SubscriptionId -ErrorAction Stop
    } else {
        Write-Host "Already connected to Azure with appropriate Tenant and Subscription" -ForegroundColor Green
    }

    # Retrieve the secret from Azure Key Vault
    $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -ErrorAction Stop
    
    # Convert secure string to plain text
    $secretValueText = $secret.SecretValue | ConvertFrom-SecureString -AsPlainText
    return $secretValueText
}

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

$SecretName = "PAT"   # Replace with the name of the secret storing the PAT
$PackagePath = "./Output/CoreUpdaterPackage.1.0.4.nupkg"  # Path to the package
$ArtifactsFeedUrl = "https://pkgs.dev.azure.com/12c/_packaging/Common/nuget/v3/index.json"  # Replace with your feed URL

# Retrieve the PAT securely
$PersonalAccessToken = Get-PATFromKeyVault -KeyVaultName $KeyVaultName -SecretName $SecretName -TenantId $TenantId -SubscriptionId $SubscriptionId

# Set up the NuGet source with the PAT
nuget.exe sources add -Name "ArtifactsFeed" -Source $ArtifactsFeedUrl -Username "AzureDevOps" -Password $PersonalAccessToken -StorePasswordInClearText

# Publish the package
nuget.exe push $PackagePath -Source "ArtifactsFeed" -ApiKey "AzureDevOps"

# Clean up the NuGet source to remove sensitive information
nuget.exe sources remove -Name "ArtifactsFeed"