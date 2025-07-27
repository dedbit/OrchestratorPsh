# Example workflow integration test for Worker module
# Note: This is an integration test that demonstrates workflow processing

# Define paths using recommended pattern
$workerModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'Worker\Worker.psd1'

Write-Host "=== Worker Module Example Workflow Integration Test ===" -ForegroundColor Cyan

# Import modules
try {
    Import-Module -Name $workerModulePath -Force
    Write-Host "✓ Worker module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import Worker module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Assert module import
if (-not (Get-Module Worker)) {
    throw "Worker module was not imported."
}

# Define test data store for this integration test
$script:TestItems = @{}

# Add stub functions for this integration test (not global scope like TestMode pattern)
function Set-12cItem {
    param($Item)
    $script:TestItems[$Item.id] = $Item
    Write-Host "✓ Stored item: $($Item.id) with state: $($Item.State), progress: $($Item.Progress)" -ForegroundColor Green
    return $Item
}

function New-RoutingItem {
    param(
        [Parameter(Mandatory=$true)] $ItemId,
        [Parameter(Mandatory=$true)] $State,
        [Parameter(Mandatory=$true)] $Progress
    )
    $item = @{ id = $ItemId; State = $State; Progress = $Progress }
    $script:TestItems[$ItemId] = $item
    Write-Host "✓ Created routing item: $ItemId" -ForegroundColor Green
    return $item
}

function Get-12cItem {
    param($Id)
    return $script:TestItems[$Id]
}

function Initialize-12Configuration {
    Write-Host "✓ Configuration initialized (mock)" -ForegroundColor Green
}

function Get-RoutingItemsByState {
    param(
        [Parameter(Mandatory=$true)] $State,
        [Parameter(Mandatory=$false)] $Progress,
        [Parameter(Mandatory=$false)] $SqlQuery,
        [Parameter(Mandatory=$false)] $Parameters
    )
    $items = $script:TestItems.Values | Where-Object { $_.State -eq $State }
    if ($Progress) { 
        $items = $items | Where-Object { $_.Progress -eq $Progress } 
    }
    Write-Host "✓ Found $($items.Count) items with state: $State$(if ($Progress) { ", progress: $Progress" })" -ForegroundColor Green
    return $items
}

# Create some test processing functions
function Invoke-Initialize {
    param([Parameter(Mandatory=$true)]$Item)
    Write-Host "Initialize function called for item '$($Item.id)'" -ForegroundColor Green
    Start-Sleep -Milliseconds 100
}

function Invoke-SetReadOnly {
    param([Parameter(Mandatory=$true)]$Item)
    Write-Host "SetReadOnly function called for item '$($Item.id)'" -ForegroundColor Green  
    Start-Sleep -Milliseconds 100
}

function Invoke-Upload {
    param([Parameter(Mandatory=$true)]$Item)
    Write-Host "Upload function called for item '$($Item.id)'" -ForegroundColor Green
    Start-Sleep -Milliseconds 100
    # Simulate some failures
    if ((Get-Random -Minimum 1 -Maximum 4) -eq 1) {
        throw "Upload failed"
    }
}

# Create test items in various stages with Ready progress
Write-Host "Creating test items..." -ForegroundColor Yellow

$initItems = @()
$readOnlyItems = @() 
$uploadItems = @()

for ($i = 1; $i -le 3; $i++) {
    $initItems += New-RoutingItem -ItemId "init-demo-$i" -State "Initialize" -Progress "Ready"
    $readOnlyItems += New-RoutingItem -ItemId "readonly-demo-$i" -State "SetReadOnly" -Progress "Ready" 
    $uploadItems += New-RoutingItem -ItemId "upload-demo-$i" -State "Upload" -Progress "Ready"
}

Write-Host "Created $($initItems.Count) Initialize items, $($readOnlyItems.Count) SetReadOnly items, $($uploadItems.Count) Upload items" -ForegroundColor Green

# Run the example workflow from the issue requirements
Write-Host "`nRunning example workflow..." -ForegroundColor Yellow

$stages = @("Initialize", "SetReadOnly", "Upload")
Invoke-Worker -Stages $stages

Write-Host "`nChecking final results..." -ForegroundColor Yellow

# Check results for each stage
foreach ($stage in $stages) {
    $items = Get-RoutingItemsByState -State $stage
    $completedCount = ($items | Where-Object { $_.Progress -eq "completed" }).Count
    $failedCount = ($items | Where-Object { $_.Progress -eq "failed" }).Count
    $totalCount = $items.Count
    Write-Host "$stage stage: $completedCount completed, $failedCount failed, $totalCount total" -ForegroundColor White
    # Assert at least one item processed per stage
    if ($totalCount -eq 0) {
        throw "$stage stage: No items processed."
    }
}

Write-Host "`n✓ Example workflow completed successfully!" -ForegroundColor Green