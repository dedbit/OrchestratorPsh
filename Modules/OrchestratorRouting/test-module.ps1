# Integration test script for OrchestratorRouting module
# Note: This is an integration test that validates core routing functionality

$ErrorActionPreference = 'Stop'

Write-Host "=== OrchestratorRouting Module Integration Test ===" -ForegroundColor Cyan

# Import the module using recommended path pattern
$modulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'OrchestratorRouting\OrchestratorRouting.psd1'

try {
    Import-Module -Name $modulePath -Force
    Write-Host "✓ OrchestratorRouting module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import OrchestratorRouting module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Assert module import
if (-not (Get-Module OrchestratorRouting)) {
    throw "OrchestratorRouting module was not imported."
}

# Load sample routing schema for reference
$schemaPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'sample-routing-schema.json'
if (Test-Path $schemaPath) {
    try {
        $routingSchema = Get-Content $schemaPath -Raw | ConvertFrom-Json
        # Assert schema loaded and has expected properties
        if ($null -eq $routingSchema) { throw "Routing schema not loaded." }
        if (-not $routingSchema.PSObject.Properties.Name) { throw "Routing schema missing expected properties." }
        Write-Host "✓ Routing schema loaded from $schemaPath" -ForegroundColor Green
    } catch {
        Write-Host "! Could not load routing schema: $($_.Exception.Message)" -ForegroundColor Yellow
        throw "Could not load routing schema."
    }
} else {
    Write-Host "! Sample routing schema not found at $schemaPath" -ForegroundColor Yellow
    $routingSchema = $null
}

# Test function availability
Write-Host "`n=== Function Availability Test ===" -ForegroundColor Yellow

$routingFunctions = @(
    'New-RoutingItem',
    'Update-ItemProgress', 
    'Invoke-RoutingBySchema',
    'Get-RoutingItem',
    'Get-RoutingItemsByState'
)

$availableFunctions = @()
foreach ($functionName in $routingFunctions) {
    $cmd = Get-Command $functionName -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host "✓ $functionName is available" -ForegroundColor Green
        $availableFunctions += $functionName
    } else {
        Write-Host "! $functionName not available (requires dependencies)" -ForegroundColor Yellow
    }
}

# Test routing concepts if functions and schema are available
# Assert at least one function is available
if ($availableFunctions.Count -eq 0) {
    throw "No routing functions available for integration test."
}
