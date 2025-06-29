# verify-config.ps1
# This script verifies that the environment configuration is properly loaded

# Define paths at top of script
$envConfigPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\environments\dev.json'

# Load environment configuration
if (Test-Path $envConfigPath) {    $envConfig = Get-Content -Path $envConfigPath -Raw | ConvertFrom-Json
    $tenantId = $envConfig.tenantId
    $subscriptionId = $envConfig.subscriptionId
    $keyVaultName = $envConfig.keyVaultName
    $resourceGroupName = $envConfig.resourceGroupName
    $location = $envConfig.location
    
    Write-Host "Environment configuration loaded successfully:" -ForegroundColor Green
    Write-Host "  Tenant ID: $tenantId" -ForegroundColor Cyan
    Write-Host "  Subscription ID: $subscriptionId" -ForegroundColor Cyan
    Write-Host "  Key Vault Name: $keyVaultName" -ForegroundColor Cyan
    Write-Host "  Resource Group Name: $resourceGroupName" -ForegroundColor Cyan
    Write-Host "  Location: $location" -ForegroundColor Cyan
    
    # Check parameter file
    $parameterFilePath = "main.parameters.json"
    if (Test-Path $parameterFilePath) {
        $parameterContent = Get-Content -Path $parameterFilePath -Raw | ConvertFrom-Json
        
        Write-Host "Parameter file configuration:" -ForegroundColor Green
        Write-Host "  Note: This file is auto-generated from environments/dev.json" -ForegroundColor Yellow
        Write-Host "  Resource Group: $($parameterContent.parameters.resourceGroupName.value)" -ForegroundColor Cyan
        Write-Host "  Key Vault: $($parameterContent.parameters.keyVaultName.value)" -ForegroundColor Cyan
        Write-Host "  Tenant ID in parameters file: $($parameterContent.parameters.tenantId.value)" -ForegroundColor Yellow
        Write-Host "  Subscription ID in parameters file: $($parameterContent.parameters.subscriptionId.value)" -ForegroundColor Yellow
          # Update parameter file with values from environment config
        $parameterContent.parameters.tenantId.value = $tenantId
        $parameterContent.parameters.subscriptionId.value = $subscriptionId
        $parameterContent.parameters.keyVaultName.value = $keyVaultName
        $parameterContent.parameters.resourceGroupName.value = $resourceGroupName
        $parameterContent.parameters.location.value = $location
        # Save updated parameters file with warning header
        $paramFileContent = @"
// -----------------------------------------------------------------
// AUTO-GENERATED FILE - DO NOT EDIT DIRECTLY
// 
// This file is automatically generated from environments/dev.json 
// by the deploy-bicep.ps1 script. Any manual changes will be lost 
// when the script runs again.
// -----------------------------------------------------------------
"@
        
        $paramJson = $parameterContent | ConvertTo-Json -Depth 10
        $paramFileContent += "`n" + $paramJson
        Set-Content -Path $parameterFilePath -Value $paramFileContent
        
        Write-Host "Updated parameter file with values from environment config." -ForegroundColor Green
        Write-Host "  Tenant ID updated to: $tenantId" -ForegroundColor Green
        Write-Host "  Subscription ID updated to: $subscriptionId" -ForegroundColor Green
        Write-Host "  Key Vault Name updated to: $keyVaultName" -ForegroundColor Green
        Write-Host "  Resource Group Name updated to: $resourceGroupName" -ForegroundColor Green
    } else {
        Write-Host "Parameter file not found at $parameterFilePath" -ForegroundColor Red
    }
} else {
    Write-Host "Environment config not found at $envConfigPath" -ForegroundColor Red
    exit 1
}

Write-Host "`nVerification complete. The configuration is ready to use." -ForegroundColor Green
