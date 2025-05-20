# verify-config.ps1
# This script verifies that the environment configuration is properly loaded

# Load environment configuration
$envConfigPath = "..\environments\dev.json"
if (Test-Path $envConfigPath) {
    $envConfig = Get-Content -Path $envConfigPath -Raw | ConvertFrom-Json
    $tenantId = $envConfig.tenantId
    $subscriptionId = $envConfig.subscriptionId
    
    Write-Host "Environment configuration loaded successfully:" -ForegroundColor Green
    Write-Host "  Tenant ID: $tenantId" -ForegroundColor Cyan
    Write-Host "  Subscription ID: $subscriptionId" -ForegroundColor Cyan
    
    # Check parameter file
    $parameterFilePath = "main.parameters.json"
    if (Test-Path $parameterFilePath) {
        $parameterContent = Get-Content -Path $parameterFilePath -Raw | ConvertFrom-Json
        
        Write-Host "Parameter file configuration:" -ForegroundColor Green
        Write-Host "  Resource Group: $($parameterContent.parameters.resourceGroupName.value)" -ForegroundColor Cyan
        Write-Host "  Key Vault: $($parameterContent.parameters.keyVaultName.value)" -ForegroundColor Cyan
        Write-Host "  Tenant ID in parameters file: $($parameterContent.parameters.tenantId.value)" -ForegroundColor Yellow
        Write-Host "  Subscription ID in parameters file: $($parameterContent.parameters.subscriptionId.value)" -ForegroundColor Yellow
        
        # Update parameter file with values from environment config
        $parameterContent.parameters.tenantId.value = $tenantId
        $parameterContent.parameters.subscriptionId.value = $subscriptionId
        $parameterContent | ConvertTo-Json -Depth 10 | Set-Content -Path $parameterFilePath
        
        Write-Host "Updated parameter file with values from environment config." -ForegroundColor Green
        Write-Host "  Tenant ID updated to: $tenantId" -ForegroundColor Green
        Write-Host "  Subscription ID updated to: $subscriptionId" -ForegroundColor Green
    } else {
        Write-Host "Parameter file not found at $parameterFilePath" -ForegroundColor Red
    }
} else {
    Write-Host "Environment config not found at $envConfigPath" -ForegroundColor Red
    exit 1
}

Write-Host "`nVerification complete. The configuration is ready to use." -ForegroundColor Green
