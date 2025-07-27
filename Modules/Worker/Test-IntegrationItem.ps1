# Integration test for Invoke-ItemProcessor with real Cosmos DB operations
Write-Host "\nIntegration Test: Invoke-ItemProcessor for 'Initialize' state with Cosmos DB..." -ForegroundColor Yellow

# Import Worker module
$workerModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'Worker\Worker.psd1'
Import-Module -Name $workerModulePath -Force

# Import CosmosDB module
$cosmosModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\CosmosDB\CosmosDBPackage\CosmosDBPackage.psd1'
Import-Module -Name $cosmosModulePath -Force

# Load environment config
$envConfigPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\..\environments\dev.json'
Initialize-12Configuration $envConfigPath

# Import OrchestratorAzure module for Connect-12AzurewithCertificate
$azureModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\OrchestratorAzure\OrchestratorAzure.psd1'
Import-Module -Name $azureModulePath -Force

# Connect to Azure
Connect-12AzurewithCertificate


# Cosmos DB connection
$connection = Get-12cCosmosConnection -DatabaseName "OrchestratorDb" -ContainerName "Items"
if ($null -eq $connection) { throw "CosmosDB connection failed" }
Write-Host "✓ Connected to CosmosDB: $($connection.AccountName)" -ForegroundColor Green

# Create a test item in Cosmos DB
$testId = "itemproc-integration-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$testItem = New-RoutingItem -ItemId $testId -State 'Initialize' -Progress 'Ready'
if ($null -eq $testItem) { throw "Failed to create test item in CosmosDB" }
Write-Host "✓ Created test item: $testId in CosmosDB" -ForegroundColor Green

# Import WorkerFunctions\Initialize.psm1 to ensure Invoke-Initialize is available
$workerFuncPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'WorkerFunctions\Initialize.psm1'
if (Test-Path $workerFuncPath) {
    Import-Module -Name $workerFuncPath -Force
    Write-Host "✓ Imported WorkerFunctions\\Initialize.psm1" -ForegroundColor Green
} else {
    Write-Host "⚠ WorkerFunctions\\Initialize.psm1 not found, Invoke-Initialize may not be available" -ForegroundColor Yellow
} 

# Call Invoke-ItemProcessor and validate result
try {
    # Invoke-ItemProcessor -Item $testItem -StageFunction { Invoke-Initialize $args[0] } -Stage 'Initialize'
    Invoke-ItemProcessor -Item $testItem -StageFunction 'Invoke-Initialize' -Stage 'Initialize'
    Write-Host "✓ Invoke-ItemProcessor called for item '$($testItem.id)' in 'Initialize' state" -ForegroundColor Green
} catch {
    Write-Host "✗ Invoke-ItemProcessor test failed: $($_.Exception.Message)" -ForegroundColor Red
    throw "Invoke-ItemProcessor invocation failed"
}

# Verify item progress in Cosmos DB
$updatedItem = Get-12cItem -Id $testId -DatabaseName "OrchestratorDb" -ContainerName "Items"
if ($updatedItem.Progress -eq "Completed") {
    Write-Host "✓ Item '$testId' progress updated to Completed in CosmosDB" -ForegroundColor Green
} else {
    Write-Host "✗ Item '$testId' progress not updated: $($updatedItem.Progress)" -ForegroundColor Red
    throw "ItemProcessor did not update item progress as expected"
}

# Clean up test item
$removeResult = Remove-12cItem -Id $testId -DatabaseName "OrchestratorDb" -ContainerName "Items"
if ($null -ne $removeResult) {
    Write-Host "✓ Cleaned up test item: $testId" -ForegroundColor Green
} else {
    Write-Host "⚠ Failed to clean up test item: $testId" -ForegroundColor Yellow
}
