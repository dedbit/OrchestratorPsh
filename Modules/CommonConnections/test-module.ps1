# test-module.ps1
# Script to test the CommonConnections module

# Define paths at top of script
$modulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'CommonConnectionsPackage\CommonConnectionsPackage.psm1'
$customConfigPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\..\environments\dev.json'

# Import the module
Import-Module -Name $modulePath -Force

# Test Get-12cConnection with default configuration
Write-Host "Testing Get-12cConnection with default configuration..." -ForegroundColor Cyan
try {
    $allConnections = Get-12cConnection
    if ($null -ne $allConnections) {
        Write-Host "✓ Get-12cConnection executed successfully - retrieved all connections." -ForegroundColor Green
        Write-Host "Available connection properties:" -ForegroundColor Yellow
        $allConnections.PSObject.Properties.Name | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
    } else {
        Write-Warning "Get-12cConnection returned null"
    }
} catch {
    Write-Error "Get-12cConnection test failed: $($_.Exception.Message)"
}

# Test Get-12cConnection with specific connection names
Write-Host "`nTesting Get-12cConnection with specific connection properties..." -ForegroundColor Cyan
$testProperties = @('tenantId', 'subscriptionId', 'keyVaultName', 'appId', 'certThumbprint')

foreach ($property in $testProperties) {
    try {
        $value = Get-12cConnection -ConnectionName $property
        if ($null -ne $value) {
            Write-Host "✓ $property`: $value" -ForegroundColor Green
        } else {
            Write-Warning "Property '$property' returned null"
        }
    } catch {
        Write-Error "Failed to get property '$property': $($_.Exception.Message)"
    }
}

# Test Get-12cConnection with custom config path
Write-Host "`nTesting Get-12cConnection with custom config path..." -ForegroundColor Cyan
try {
    $customConfig = Get-12cConnection -ConfigFilePathOverride $customConfigPath
    if ($null -ne $customConfig) {
        Write-Host "✓ Get-12cConnection executed successfully with custom config path." -ForegroundColor Green
    } else {
        Write-Warning "Get-12cConnection with custom path returned null"
    }
} catch {
    Write-Error "Get-12cConnection with custom path test failed: $($_.Exception.Message)"
}

# Test accessing nested properties (future-proofing for Azure App Configuration)
Write-Host "`nTesting access to potential nested connection structures..." -ForegroundColor Cyan
try {
    # Test if we can access the configuration as if it had nested structures
    $allConfig = Get-12cConnection
    if ($allConfig.PSObject.Properties.Name -contains 'artifactsFeedUrl') {
        $feedUrl = Get-12cConnection -ConnectionName 'artifactsFeedUrl'
        Write-Host "✓ Artifacts Feed URL: $feedUrl" -ForegroundColor Green
    }
} catch {
    Write-Warning "Nested property access test completed with warning: $($_.Exception.Message)"
}

Write-Host "`nCommonConnections module testing completed." -ForegroundColor Cyan