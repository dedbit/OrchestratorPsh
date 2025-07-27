# test-integration.ps1
# Integration test script for the Worker module with real Cosmos DB operations

# Helper function for assertions
function Assert-StringNotEmpty {
    param([string]$Value, [string]$Name)
    if ([string]::IsNullOrEmpty($Value)) {
        Write-Host "✗ Assertion failed: $Name cannot be null or empty" -ForegroundColor Red
        throw "$Name cannot be null or empty"
    }
}

function Assert-ObjectNotNull {
    param([object]$Value, [string]$Name)
    if ($null -eq $Value) {
        Write-Host "✗ Assertion failed: $Name cannot be null" -ForegroundColor Red
        throw "$Name cannot be null"
    }
}

function Assert-Equal {
    param([object]$Expected, [object]$Actual, [string]$Name)
    if ($Expected -ne $Actual) {
        Write-Host "✗ Assertion failed: $Name expected '$Expected' but got '$Actual'" -ForegroundColor Red
        throw "$Name expected '$Expected' but got '$Actual'"
    }
}

# Define paths at top of script
$workerModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'Worker\Worker.psd1'
$orchestratorRoutingModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\OrchestratorRouting\OrchestratorRouting\OrchestratorRouting.psd1'
$configurationModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\Configuration\ConfigurationPackage\ConfigurationPackage.psd1'
$orchestratorAzureModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\OrchestratorAzure\OrchestratorAzure.psd1'
$cosmosModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\CosmosDB\CosmosDBPackage\CosmosDBPackage.psd1'
$envConfigPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\..\environments\dev.json'

Write-Host "Starting Worker integration tests..." -ForegroundColor Cyan

# Import modules and initialize
try {
    Import-Module -Name $configurationModulePath -Force
    Import-Module -Name $orchestratorAzureModulePath -Force
    Import-Module -Name $cosmosModulePath -Force
    Import-Module -Name $orchestratorRoutingModulePath -Force
    Import-Module -Name $workerModulePath -Force
    Write-Host "✓ All modules imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import modules: $($_.Exception.Message)" -ForegroundColor Red
    throw "Module import failed"
}

# Initialize configuration and Azure connection
try {
    Initialize-12Configuration $envConfigPath
    #Connect-12Azure
    Connect-12AzureWithCertificate
    Write-Host "✓ Azure connection established" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to connect to Azure: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "⚠ This test requires Azure authentication. Please ensure:" -ForegroundColor Yellow
    Write-Host "  - Valid Azure credentials are available" -ForegroundColor Yellow
    Write-Host "  - Certificate is properly installed" -ForegroundColor Yellow
    Write-Host "  - Environment configuration is correct" -ForegroundColor Yellow
    throw "Azure connection failed"
}

# Test connection to Cosmos DB
try {
    $connection = Get-12cCosmosConnection -DatabaseName "OrchestratorDb" -ContainerName "Items"
    Assert-ObjectNotNull $connection "CosmosDB Connection"
    Assert-StringNotEmpty $connection.AccountName "CosmosDB AccountName"
    Write-Host "✓ Connected to CosmosDB: $($connection.AccountName)" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to connect to CosmosDB: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "⚠ This test requires access to CosmosDB 'OrchestratorDb' database" -ForegroundColor Yellow
    throw "CosmosDB connection failed"
}

# Create test items for each stage with Ready progress
$testTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$testItems = @()
$failedCreations = 0


# Create items for the three default stages
$stages = @("initialize", "setreadonly", "upload")
foreach ($stage in $stages) {
    for ($i = 1; $i -le 2; $i++) {
        try {
            $testId = "worker-test-$stage-$i-$testTimestamp"
            $testItem = New-RoutingItem -ItemId $testId -State $stage -Progress "ready"
            Assert-ObjectNotNull $testItem "Created test item"
            Assert-StringNotEmpty $testItem.id "Test item ID"
            Assert-Equal $stage $testItem.State "Test item State"
            Assert-Equal "ready" $testItem.Progress "Test item Progress"
            $testItems += $testItem
            Write-Host "✓ Created test item: $testId in stage '$stage' with progress 'ready'" -ForegroundColor Green
        } catch {
            $failedCreations++
            Write-Host "✗ Failed to create test item in stage '$stage': $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

if ($failedCreations -gt 0) {
    throw "Failed to create $failedCreations test items"
}

Write-Host "✓ Created $($testItems.Count) test items" -ForegroundColor Green

# Verify items exist in Cosmos DB before processing
Write-Host "Verifying test items exist in Cosmos DB..." -ForegroundColor Yellow
foreach ($stage in $stages) {
    $items = Get-RoutingItemsByState -State $stage -Progress "Ready"
    $testItemsInStage = $items | Where-Object { $_.id -like "*worker-test-$stage-*-$testTimestamp" }
    if ($testItemsInStage.Count -lt 2) {
        throw "Expected at least 2 test items in stage '$stage' but found $($testItemsInStage.Count)"
    }
    Write-Host "✓ Found $($testItemsInStage.Count) test items in stage '$stage' with Ready progress" -ForegroundColor Green
}

# Create mock processing functions for the Worker to use
function Invoke-Initialize {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Item)
    Write-Host "Processing Initialize for item '$($Item.id)'" -ForegroundColor White
    Start-Sleep -Milliseconds 100
}

function Invoke-SetReadOnly {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Item)
    Write-Host "Processing SetReadOnly for item '$($Item.id)'" -ForegroundColor White
    Start-Sleep -Milliseconds 100
}

function Invoke-Upload {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Item)
    Write-Host "Processing Upload for item '$($Item.id)'" -ForegroundColor White
    Start-Sleep -Milliseconds 100
}

# Create a stage function map using scriptblocks for correct scoping
$stageFunctionMap = @{
    "initialize" = { Invoke-Initialize $args[0] }
    "setreadonly" = { Invoke-SetReadOnly $args[0] }
    "upload" = { Invoke-Upload $args[0] }
}

# Invoke the worker process to process the test items
Write-Host "Invoking Worker to process test items..." -ForegroundColor Yellow
try {
    foreach ($stage in $stages) {
        Invoke-StageProcessor -Stage $stage -StageFunctionMap $stageFunctionMap
    }
    Write-Host "✓ Worker processing completed" -ForegroundColor Green
} catch {
    Write-Host "✗ Worker processing failed: $($_.Exception.Message)" -ForegroundColor Red
    # Continue to cleanup even if worker failed
}

# Verify that item states have changed as expected
Write-Host "Verifying item progress has changed..." -ForegroundColor Yellow
$processedCount = 0
$completedCount = 0
$failedCount = 0
$verificationErrors = 0

foreach ($testItem in $testItems) {
    try {
        # Retrieve the updated item from Cosmos DB
        $updatedItem = Get-12cItem -Id $testItem.id -DatabaseName "OrchestratorDb" -ContainerName "Items"
        Assert-ObjectNotNull $updatedItem "Updated test item"
        
        # Verify the progress has changed from Ready
        if ($updatedItem.Progress -ne "Ready") {
            $processedCount++
            if ($updatedItem.Progress -eq "Completed") {
                $completedCount++
            } elseif ($updatedItem.Progress -eq "Failed") {
                $failedCount++
            }
        }
        
        Write-Host "✓ Item '$($testItem.id)' progress: $($updatedItem.Progress)" -ForegroundColor Green
    } catch {
        $verificationErrors++
        Write-Host "✗ Failed to verify item '$($testItem.id)': $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Verify that all items were processed (progress changed from Ready)
if ($verificationErrors -eq 0 -and $processedCount -ne $testItems.Count) {
    Write-Host "✗ Error: Expected all $($testItems.Count) items to be processed, but only $processedCount were processed" -ForegroundColor Red
    throw "Test failed: Not all items were processed"
} else {
    Write-Host "✓ All $processedCount test items were processed ($completedCount completed, $failedCount failed)" -ForegroundColor Green
}

# Clean up the test items
Write-Host "Cleaning up test items..." -ForegroundColor Yellow
$cleanupCount = 0
foreach ($testItem in $testItems) {
    try {
        $removeResult = Remove-12cItem -Id $testItem.id -DatabaseName "OrchestratorDb" -ContainerName "Items"
        Assert-ObjectNotNull $removeResult "Remove-12cItem result"
        $cleanupCount++
        Write-Host "✓ Cleaned up test item: $($testItem.id)" -ForegroundColor Green
    } catch {
        Write-Host "⚠ Failed to clean up test item '$($testItem.id)': $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "✓ Cleaned up $cleanupCount/$($testItems.Count) test items" -ForegroundColor Green

Write-Host "Worker integration tests complete." -ForegroundColor Cyan

