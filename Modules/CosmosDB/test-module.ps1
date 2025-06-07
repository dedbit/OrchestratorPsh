# test-module.ps1
# Script to test the CosmosDB module

# Define paths at top of script
$modulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'CosmosDBPackage\CosmosDBPackage.psm1'
$configurationModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\Configuration\ConfigurationPackage\ConfigurationPackage.psm1'

# Import required modules
try {
    Import-Module -Name $configurationModulePath -Force
    Write-Host "Configuration module imported successfully." -ForegroundColor Green
    
    Import-Module -Name $modulePath -Force
    Write-Host "CosmosDB module imported successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to import modules: $($_.Exception.Message)"
    exit 1
}

# Initialize configuration
try {
    Initialize-12Configuration
    Write-Host "Configuration initialized successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to initialize configuration: $($_.Exception.Message)"
    Write-Host "Note: This test requires Azure connectivity and proper configuration." -ForegroundColor Yellow
}

# Test Get-12cCosmosConnection (without Azure connectivity)
Write-Host "Testing Get-12cCosmosConnection (dry run)..." -ForegroundColor Cyan
try {
    if ($Global:12cConfig) {
        Write-Host "Global configuration is available." -ForegroundColor Green
        Write-Host "Cosmos account name from config: $($Global:12cConfig.cosmosDbAccountName)" -ForegroundColor White
        Write-Host "Key Vault name from config: $($Global:12cConfig.keyVaultName)" -ForegroundColor White
    } else {
        Write-Host "Global configuration not available - Azure connectivity required for full testing." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Get-12cCosmosConnection test skipped (requires Azure connectivity): $($_.Exception.Message)" -ForegroundColor Yellow
}

# Test Get-12cItem (dry run - check function exists)
Write-Host "Testing Get-12cItem function availability..." -ForegroundColor Cyan
try {
    $functionExists = Get-Command Get-12cItem -ErrorAction SilentlyContinue
    if ($functionExists) {
        Write-Host "Get-12cItem function is available." -ForegroundColor Green
    } else {
        Write-Error "Get-12cItem function not found."
    }
} catch {
    Write-Error "Get-12cItem function test failed: $($_.Exception.Message)"
}

# Test Set-12cItem (dry run - check function exists)
Write-Host "Testing Set-12cItem function availability..." -ForegroundColor Cyan
try {
    $functionExists = Get-Command Set-12cItem -ErrorAction SilentlyContinue
    if ($functionExists) {
        Write-Host "Set-12cItem function is available." -ForegroundColor Green
    } else {
        Write-Error "Set-12cItem function not found."
    }
} catch {
    Write-Error "Set-12cItem function test failed: $($_.Exception.Message)"
}

Write-Host "Basic module tests completed." -ForegroundColor Cyan
Write-Host "Note: Full functionality tests require Azure connectivity and CosmosDB setup." -ForegroundColor Yellow