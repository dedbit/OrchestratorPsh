# test-module.ps1
# Integration test script for the CosmosDB module
# Note: This is an integration test that validates module loading and function availability

# Define paths at top of script using recommended pattern
$modulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'CosmosDBPackage\CosmosDBPackage.psm1'
$configurationModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\Configuration\ConfigurationPackage\ConfigurationPackage.psm1'

Write-Host "=== CosmosDB Module Integration Test ===" -ForegroundColor Cyan

# Import required modules
try {
    Import-Module -Name $configurationModulePath -Force
    Write-Host "✓ Configuration module imported successfully" -ForegroundColor Green
    
    Import-Module -Name $modulePath -Force
    Write-Host "✓ CosmosDB module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import modules: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Initialize configuration
try {
    Initialize-12Configuration
    Write-Host "✓ Configuration initialized successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to initialize configuration: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Note: This test requires Azure connectivity and proper configuration" -ForegroundColor Yellow
}

# Verify expected functions are available
Write-Host "`nVerifying function availability..." -ForegroundColor Cyan

$expectedFunctions = @(
    'Get-12cCosmosConnection',
    'Get-12cItem', 
    'Set-12cItem',
    'Invoke-12cCosmosDbSqlQuery'
)

$missingFunctions = @()
foreach ($functionName in $expectedFunctions) {
    if (Get-Command $functionName -ErrorAction SilentlyContinue) {
        Write-Host "✓ $functionName function is available" -ForegroundColor Green
    } else {
        Write-Host "✗ $functionName function not found" -ForegroundColor Red
        $missingFunctions += $functionName
    }
}

if ($missingFunctions.Count -gt 0) {
    Write-Host "✗ Missing functions: $($missingFunctions -join ', ')" -ForegroundColor Red
    exit 1
}

# Test configuration availability (dry run)
Write-Host "`nTesting configuration availability..." -ForegroundColor Cyan
if ($Global:12cConfig) {
    Write-Host "✓ Global configuration is available" -ForegroundColor Green
    if ($Global:12cConfig.cosmosDbAccountName) {
        Write-Host "  - Cosmos account name: $($Global:12cConfig.cosmosDbAccountName)" -ForegroundColor White
    }
    if ($Global:12cConfig.keyVaultName) {
        Write-Host "  - Key Vault name: $($Global:12cConfig.keyVaultName)" -ForegroundColor White
    }
} else {
    Write-Host "! Global configuration not available - Azure connectivity required for full testing" -ForegroundColor Yellow
}

Write-Host "`n✓ CosmosDB module integration test completed successfully" -ForegroundColor Green
Write-Host "Note: Full functionality tests require Azure connectivity and CosmosDB setup" -ForegroundColor Yellow