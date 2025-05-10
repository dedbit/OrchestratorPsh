# New session. Sign in as app

# Load environment configuration from environments/dev.json
$configPath = "..\..\environments\dev.json" # Adjust the path as needed
$config = Get-Content -Path $configPath | ConvertFrom-Json

# The $config object now contains all properties from the JSON file and can be accessed directly.

$keyVaultName = $config.keyVaultName # Replace with your Key Vault name
$resourceGroupName = $config.resourceGroupName # Replace with your Resource Group name

Connect-AzAccount -ServicePrincipal -CertificateThumbprint $config.certThumbprint -ApplicationId $config.AppId -TenantId $config.tenantId


# Step 6: Get a secret from Azure Key Vault
Write-Host "Getting a secret from Azure Key Vault..." -ForegroundColor Green

# Define secret name
$secretName = "PAT" # Replace with your secret name

# Get the secret
$secret = Get-AzKeyVaultSecret -VaultName $config.keyVaultName -Name $secretName
Write-Host "Secret value retrieved: $($secret.SecretValueText)" -ForegroundColor Green

# Step 7: List secrets in Azure Key Vault
Write-Host "Listing secrets in Azure Key Vault..." -ForegroundColor Green

# List all secrets
$secrets = Get-AzKeyVaultSecret -VaultName $config.keyVaultName
Write-Host "Secrets in Key Vault:" -ForegroundColor Green
$secrets | ForEach-Object { Write-Host $_.Name }