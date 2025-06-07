# test-integration.ps1
# Integration test script for the CosmosDB module with real Cosmos DB operations

# Helper function for assertions
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

# Define paths at top of script
$modulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'CosmosDBPackage\CosmosDBPackage.psd1'
$configurationModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\Configuration\ConfigurationPackage\ConfigurationPackage.psd1'
$orchestratorAzureModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\OrchestratorAzure\OrchestratorAzure.psd1'
$envConfigPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\..\environments\dev.json'

Write-Host "Starting CosmosDB integration tests..." -ForegroundColor Cyan

# Import modules and initialize
Import-Module -Name $configurationModulePath -Force
Import-Module -Name $orchestratorAzureModulePath -Force
Import-Module -Name $modulePath -Force
Initialize-12Configuration $envConfigPath
Connect-12Azure

# Test connection
$connection = Get-12cCosmosConnection -DatabaseName "OrchestratorDb" -ContainerName "Items"
Write-Host "✓ Connected to CosmosDB: $($connection.AccountName)" -ForegroundColor Green

# Create test item
$testId = "test-item-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$testItem = @{
    id = $testId
    name = "Test"
    description = "Created by integration test"
    timestamp = (Get-Date).ToString("o")
}

$result = Set-12cItem -Item $testItem -DatabaseName "OrchestratorDb" -ContainerName "Items"
Write-Host "✓ Item upserted: $testId" -ForegroundColor Green

# Retrieve test item
$retrieved = Get-12cItem -Id $testId -DatabaseName "OrchestratorDb" -ContainerName "Items"
Write-Host "✓ Item retrieved: $($retrieved.id) - $($retrieved.name)" -ForegroundColor Green

# Clean up the test item
try {
    Remove-12cItem -Id $testId -DatabaseName "OrchestratorDb" -ContainerName "Items"
    Write-Host "✓ Test item cleaned up: $testId" -ForegroundColor Green
} catch {
    Write-Host "⚠ Failed to clean up test item: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "Integration tests complete." -ForegroundColor Cyan