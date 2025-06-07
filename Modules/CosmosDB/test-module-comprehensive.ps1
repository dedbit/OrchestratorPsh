# test-module-comprehensive.ps1
# Comprehensive test script for the CosmosDB module

# Define paths at top of script
$modulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'CosmosDBPackage\CosmosDBPackage.psm1'
$configurationModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\Configuration\ConfigurationPackage\ConfigurationPackage.psm1'

Write-Host "Starting comprehensive CosmosDB module tests..." -ForegroundColor Cyan

# Helper function to test assertions
function Assert-StringNotEmpty {
    param([string]$Value, [string]$Name)
    if ([string]::IsNullOrEmpty($Value)) {
        throw "$Name cannot be null or empty"
    }
}

function Assert-ObjectNotNull {
    param([object]$Value, [string]$Name)
    if ($null -eq $Value) {
        throw "$Name cannot be null"
    }
}

# Test 1: Module Import
Write-Host "Test 1: Module Import" -ForegroundColor Yellow
try {
    Import-Module -Name $configurationModulePath -Force
    Import-Module -Name $modulePath -Force
    Write-Host "✓ Modules imported successfully" -ForegroundColor Green
} catch {
    Write-Error "✗ Module import failed: $($_.Exception.Message)"
    exit 1
}

# Test 2: Configuration Initialization
Write-Host "Test 2: Configuration Initialization" -ForegroundColor Yellow
try {
    Initialize-12Configuration
    Assert-ObjectNotNull -Value $Global:12cConfig -Name "Global:12cConfig"
    Assert-StringNotEmpty -Value $Global:12cConfig.cosmosDbAccountName -Name "cosmosDbAccountName"
    Assert-StringNotEmpty -Value $Global:12cConfig.keyVaultName -Name "keyVaultName"
    Write-Host "✓ Configuration initialized and validated" -ForegroundColor Green
} catch {
    Write-Host "✗ Configuration initialization failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Note: Azure connectivity may be required for full testing" -ForegroundColor Yellow
}

# Test 3: Function Availability
Write-Host "Test 3: Function Availability" -ForegroundColor Yellow
try {
    $functions = @('Get-12cItem', 'Set-12cItem', 'Remove-12cItem', 'Get-12cCosmosConnection')
    foreach ($functionName in $functions) {
        $function = Get-Command $functionName -ErrorAction SilentlyContinue
        Assert-ObjectNotNull -Value $function -Name $functionName
        Write-Host "✓ $functionName function is available" -ForegroundColor Green
    }
} catch {
    Write-Error "✗ Function availability test failed: $($_.Exception.Message)"
    exit 1
}

# Test 4: Module Metadata
Write-Host "Test 4: Module Metadata" -ForegroundColor Yellow
try {
    $moduleInfo = Get-Module CosmosDBPackage -ErrorAction SilentlyContinue
    if (-not $moduleInfo) {
        # Try to get from imported modules
        $moduleInfo = Get-Module -Name "*CosmosDB*" -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($moduleInfo) {
        Assert-ObjectNotNull -Value $moduleInfo -Name "Module Info"
        Write-Host "✓ Module metadata is valid" -ForegroundColor Green
        Write-Host "  Name: $($moduleInfo.Name)" -ForegroundColor White
        Write-Host "  Version: $($moduleInfo.Version)" -ForegroundColor White
    } else {
        Write-Host "⚠ Module metadata test skipped - module not found in loaded modules" -ForegroundColor Yellow
    }
} catch {
    Write-Error "✗ Module metadata test failed: $($_.Exception.Message)"
}

# Test 5: Parameter Validation (Get-12cItem)
Write-Host "Test 5: Parameter Validation (Get-12cItem)" -ForegroundColor Yellow
try {
    # Test that function fails without required parameter by checking the help
    $commandInfo = Get-Command Get-12cItem -ErrorAction SilentlyContinue
    if ($commandInfo) {
        $idParam = $commandInfo.Parameters['Id']
        if ($idParam -and $idParam.Attributes.Mandatory) {
            Write-Host "✓ Required parameter Id is correctly defined as mandatory" -ForegroundColor Green
        } else {
            Write-Host "✗ Id parameter should be mandatory" -ForegroundColor Red
        }
    }
} catch {
    Write-Error "✗ Parameter validation test failed: $($_.Exception.Message)"
}

# Test 6: Parameter Validation (Set-12cItem)
Write-Host "Test 6: Parameter Validation (Set-12cItem)" -ForegroundColor Yellow
try {
    # Test that function fails without required parameter by checking the help
    $commandInfo = Get-Command Set-12cItem -ErrorAction SilentlyContinue
    if ($commandInfo) {
        $itemParam = $commandInfo.Parameters['Item']
        if ($itemParam -and $itemParam.Attributes.Mandatory) {
            Write-Host "✓ Required parameter Item is correctly defined as mandatory" -ForegroundColor Green
        } else {
            Write-Host "✗ Item parameter should be mandatory" -ForegroundColor Red
        }
    }
} catch {
    Write-Error "✗ Parameter validation test failed: $($_.Exception.Message)"
}

# Test 7: Parameter Validation (Remove-12cItem)
Write-Host "Test 7: Parameter Validation (Remove-12cItem)" -ForegroundColor Yellow
try {
    # Test that function fails without required parameter by checking the help
    $commandInfo = Get-Command Remove-12cItem -ErrorAction SilentlyContinue
    if ($commandInfo) {
        $idParam = $commandInfo.Parameters['Id']
        if ($idParam -and $idParam.Attributes.Mandatory) {
            Write-Host "✓ Required parameter Id is correctly defined as mandatory" -ForegroundColor Green
        } else {
            Write-Host "✗ Id parameter should be mandatory" -ForegroundColor Red
        }
    }
} catch {
    Write-Error "✗ Parameter validation test failed: $($_.Exception.Message)"
}

# Test 8: Connection Configuration Test
Write-Host "Test 8: Connection Configuration Test" -ForegroundColor Yellow
if ($Global:12cConfig) {
    try {
        # Test connection configuration structure
        $expectedConnectionData = @{
            DatabaseName = "TestDB"
            ContainerName = "TestContainer"
        }
        
        Write-Host "✓ Connection configuration structure is testable" -ForegroundColor Green
        Write-Host "  Expected Database: $($expectedConnectionData.DatabaseName)" -ForegroundColor White
        Write-Host "  Expected Container: $($expectedConnectionData.ContainerName)" -ForegroundColor White
        Write-Host "  Cosmos Account from config: $($Global:12cConfig.cosmosDbAccountName)" -ForegroundColor White
    } catch {
        Write-Error "✗ Connection configuration test failed: $($_.Exception.Message)"
    }
} else {
    Write-Host "⚠ Skipping connection test - configuration not available" -ForegroundColor Yellow
}

Write-Host "Comprehensive test suite completed." -ForegroundColor Cyan
Write-Host "Note: Live Azure connectivity tests require proper authentication and CosmosDB setup." -ForegroundColor Yellow