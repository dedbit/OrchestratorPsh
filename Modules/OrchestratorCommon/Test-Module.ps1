# test-module.ps1
# Integration test script for the OrchestratorCommon wrapper module functionality
# Note: This is an integration test that validates module loading and function availability

# Define paths at top of script using recommended pattern
$scriptRoot = $PSScriptRoot ? $PSScriptRoot : (Get-Location).Path
$azureModulePath = Join-Path $scriptRoot '..\OrchestratorAzure\OrchestratorAzure.psd1'
$modulePath = Join-Path $scriptRoot 'OrchestratorCommon.psd1'
$envConfigPath = Join-Path $scriptRoot '..\..\environments\dev.json'

Write-Host "=== OrchestratorCommon Module Integration Test ===" -ForegroundColor Cyan

# Verify OrchestratorAzure module exists
if (-not (Test-Path $azureModulePath)) {
    Write-Host "✗ OrchestratorAzure module not found at $azureModulePath. This is required by OrchestratorCommon." -ForegroundColor Red
    exit 1
} else {
    Write-Host "✓ OrchestratorAzure module found at $azureModulePath" -ForegroundColor Green
}

# Import the OrchestratorCommon module (which should load OrchestratorAzure)
try {
    Import-Module -Name $modulePath -Force
    Write-Host "✓ OrchestratorCommon module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import OrchestratorCommon module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Assert module import
if (-not (Get-Module OrchestratorCommon)) {
    throw "OrchestratorCommon module was not imported."
}

# Show available functions in the OrchestratorCommon module
$moduleFunctions = Get-Command -Module OrchestratorCommon -ErrorAction SilentlyContinue
if ($moduleFunctions) {
    Write-Host "✓ Functions available in OrchestratorCommon module:" -ForegroundColor Cyan
    $moduleFunctions | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Yellow }
} else {
    Write-Host "! No functions found in OrchestratorCommon module" -ForegroundColor Yellow
}

# Verify OrchestratorAzure was loaded and check its functions
$azureModuleFunctions = Get-Command -Module OrchestratorAzure -ErrorAction SilentlyContinue
if ($azureModuleFunctions) {
    Write-Host "✓ OrchestratorAzure module was successfully loaded by OrchestratorCommon" -ForegroundColor Green
    Write-Host "Functions in OrchestratorAzure module:" -ForegroundColor Cyan
    $azureModuleFunctions | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Yellow }
    # Assert at least one function exists
    if ($azureModuleFunctions.Count -eq 0) {
        throw "No functions found in OrchestratorAzure module."
    }
} else {
    Write-Host "! OrchestratorAzure module was not loaded properly" -ForegroundColor Yellow
    throw "OrchestratorAzure module was not loaded properly."
}

# Test configuration availability if environment config exists
if (Test-Path $envConfigPath) {
    try {
        # Load environment config
        $envConfig = Get-Content -Path $envConfigPath -Raw | ConvertFrom-Json
        $KeyVaultName = $envConfig.keyVaultName
        $TenantId = $envConfig.tenantId
        $SubscriptionId = $envConfig.subscriptionId

        # Assert config values
        if ([string]::IsNullOrEmpty($KeyVaultName)) { throw "KeyVaultName missing in environment config." }
        if ([string]::IsNullOrEmpty($TenantId)) { throw "TenantId missing in environment config." }
        if ([string]::IsNullOrEmpty($SubscriptionId)) { throw "SubscriptionId missing in environment config." }

        Write-Host "`n✓ Environment configuration loaded:" -ForegroundColor Green
        Write-Host "  - Key Vault: $KeyVaultName" -ForegroundColor White
        Write-Host "  - Tenant ID: $TenantId" -ForegroundColor White
        Write-Host "  - Subscription ID: $SubscriptionId" -ForegroundColor White

        # Note: Skipping interactive Azure connection test to avoid login prompt in integration test
        Write-Host "`nℹ Skipping interactive Azure connection test to avoid login prompt" -ForegroundColor Yellow
        Write-Host "  (Integration tests with real Azure connectivity should be run manually)" -ForegroundColor Yellow

    } catch {
        Write-Host "! Failed to load environment config: $($_.Exception.Message)" -ForegroundColor Yellow
        throw "Failed to load environment config."
    }
} else {
    Write-Host "`n! Environment config not found at $envConfigPath" -ForegroundColor Yellow
    Write-Host "  Configuration file is needed for full integration testing" -ForegroundColor Yellow
}

Write-Host "`n✓ OrchestratorCommon module integration test completed successfully" -ForegroundColor Green
