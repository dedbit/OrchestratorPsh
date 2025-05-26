# test-keyvault-fixed.ps1
# Script to test the Get-PATFromKeyVault function

# Import the Az module
# Import-Module Az

Import-Module ..\Modules\Configuration\ConfigurationPackage.psd1
Import-Module ..\Modules\OrchestratorAzure\OrchestratorAzure.psd1
Initialize-12Configuration ..\environments\dev.json
Connect-12Azure

# Import OrchestratorCommon module
$moduleRoot = Join-Path -Path $PSScriptRoot -ChildPath "..\Modules\OrchestratorCommon"
if (Test-Path $moduleRoot) {
    Import-Module $moduleRoot -Force
    Write-Host "OrchestratorCommon module imported successfully." -ForegroundColor Green
} else {
    Write-Error "OrchestratorCommon module not found at $moduleRoot. Make sure the module is installed correctly."
    exit 1
}

# Get environment config
$envConfigPath = Join-Path -Path $PSScriptRoot -ChildPath "..\environments\dev.json"
if (Test-Path $envConfigPath) {
    $envConfig = Get-Content -Path $envConfigPath -Raw | ConvertFrom-Json
    $KeyVaultName = $envConfig.keyVaultName
    $TenantId = $envConfig.tenantId
    $SubscriptionId = $envConfig.subscriptionId
    
    Write-Host "Environment configuration loaded successfully." -ForegroundColor Green
    Write-Host "Using Key Vault: $KeyVaultName" -ForegroundColor Cyan
    Write-Host "Using Tenant ID: $TenantId" -ForegroundColor Cyan
    Write-Host "Using Subscription ID: $SubscriptionId" -ForegroundColor Cyan
} else {
    Write-Error "Could not find environment config at $envConfigPath. Aborting test."
    exit 1
}

# Test Standard Login
Write-Host "`n========== TEST 1: Using existing context ==========`n" -ForegroundColor Magenta
Write-Host "Testing PAT retrieval from Key Vault..." -ForegroundColor Cyan
$SecretName = "PAT"
$PersonalAccessToken = Get-PATFromKeyVault -KeyVaultName $KeyVaultName -SecretName $SecretName -TenantId $TenantId -SubscriptionId $SubscriptionId

if ($PersonalAccessToken) {
    $maskedValue = $PersonalAccessToken.Substring(0, [Math]::Min(4, $PersonalAccessToken.Length)) + "..."
    Write-Host "PAT retrieved successfully! Value (masked): $maskedValue" -ForegroundColor Green
} else {
    Write-Host "Failed to retrieve PAT." -ForegroundColor Red
}

# Test Force Login (only uncomment if you want to test the forced login functionality)
# Write-Host "`n========== TEST 2: Forcing new login ==========`n" -ForegroundColor Magenta
# $PersonalAccessToken2 = Get-PATFromKeyVault -KeyVaultName $KeyVaultName -SecretName $SecretName -TenantId $TenantId -SubscriptionId $SubscriptionId -ForceNewLogin

Write-Host "`nTest script completed!" -ForegroundColor Green
