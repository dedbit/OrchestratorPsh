# test-integration-with-module.ps1
# Combined script: defines CosmosDB functions and runs integration tests

function Get-12cCosmosConnection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$DatabaseName = "12cOrchestrator",
        [Parameter(Mandatory = $false)]
        [string]$ContainerName = "Items"
    )

    if (-not $Global:12cConfig) {
        throw "Global configuration not found. Please run Initialize-12Configuration first."
    }

    $keyVaultName = $Global:12cConfig.keyVaultName
    $cosmosAccountName = $Global:12cConfig.cosmosDbAccountName

    $connectionString = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name "CosmosDbConnectionString" -AsPlainText
    if (-not $connectionString) {
        throw "CosmosDB connection string not found in Key Vault."
    }

    return @{
        ConnectionString = $connectionString
        AccountName = $cosmosAccountName
        DatabaseName = $DatabaseName
        ContainerName = $ContainerName
    }
}

function Get-12cItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Id,
        [Parameter(Mandatory = $false)]
        [string]$PartitionKey,
        [Parameter(Mandatory = $false)]
        [string]$DatabaseName = "12cOrchestrator",
        [Parameter(Mandatory = $false)]
        [string]$ContainerName = "Items"
    )

    $conn = Get-12cCosmosConnection -DatabaseName $DatabaseName -ContainerName $ContainerName
    if (-not $PartitionKey) { $PartitionKey = $Id }

    $accountEndpoint = ($conn.ConnectionString -split 'AccountEndpoint=')[1] -split ';' | Select-Object -First 1
    $accountKey = ($conn.ConnectionString -split 'AccountKey=')[1] -split ';' | Select-Object -First 1

    $resourcePath = "dbs/$DatabaseName/colls/$ContainerName/docs/$Id"
    $date = [DateTime]::UtcNow.ToString("r")
    $verb = "GET"
    $stringToSign = "$($verb.ToLower())`ndocs`n$resourcePath`n$($date.ToLower())`n`n"

    $hmacSha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacSha.Key = [Convert]::FromBase64String($accountKey)
    $hash = $hmacSha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign))
    $sig = [Convert]::ToBase64String($hash)
    $auth = "type=master&ver=1.0&sig=$sig"

    $headers = @{
        Authorization     = [System.Web.HttpUtility]::UrlEncode($auth)  # URL-encode for CosmosDB REST API
        "x-ms-date"       = $date
        "x-ms-version"    = "2018-12-31"
        "x-ms-documentdb-partitionkey" = '["' + $PartitionKey + '"]'
    }

    $uri = "$($accountEndpoint.TrimEnd('/'))/$resourcePath"
    return Invoke-RestMethod -Uri $uri -Headers $headers -Method GET
}

function Set-12cItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Item,
        [Parameter(Mandatory = $false)]
        [string]$DatabaseName = "12cOrchestrator",
        [Parameter(Mandatory = $false)]
        [string]$ContainerName = "Items"
    )

    $conn = Get-12cCosmosConnection -DatabaseName $DatabaseName -ContainerName $ContainerName
    if (-not $Item.id) { throw "Item must have an 'id' property." }
    if (-not $Item.partitionKey) { throw "Item must have a 'partitionKey' property." }

    $accountEndpoint = ($conn.ConnectionString -split 'AccountEndpoint=')[1] -split ';' | Select-Object -First 1
    $accountKey = ($conn.ConnectionString -split 'AccountKey=')[1] -split ';' | Select-Object -First 1

    $resourcePath = "dbs/$DatabaseName/colls/$ContainerName"
    $uri = "$($accountEndpoint.TrimEnd('/'))/$resourcePath/docs"
    $date = [DateTime]::UtcNow.ToString("r")
    $verb = "POST"
    $stringToSign = "$($verb.ToLower())`ndocs`n$resourcePath`n$($date.ToLower())`n`n"

    $hmacSha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacSha.Key = [Convert]::FromBase64String($accountKey)
    $hash = $hmacSha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign))
    $sig = [Convert]::ToBase64String($hash)
    $auth = "type=master&ver=1.0&sig=$sig"

    $headers = @{
        Authorization     = [System.Web.HttpUtility]::UrlEncode($auth)
        "x-ms-date"       = $date
        "x-ms-version"    = "2018-12-31"
        "x-ms-documentdb-is-upsert" = "true"
        "x-ms-documentdb-partitionkey" = '["' + $Item.partitionKey + '"]'
        "Content-Type"    = "application/json"
    }

    $body = $Item | ConvertTo-Json -Depth 10
    return Invoke-RestMethod -Uri $uri -Headers $headers -Method POST -Body $body
}

function Remove-12cItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Id,
        [Parameter(Mandatory = $false)]
        [string]$PartitionKey,
        [Parameter(Mandatory = $false)]
        [string]$DatabaseName = "12cOrchestrator",
        [Parameter(Mandatory = $false)]
        [string]$ContainerName = "Items"
    )

    $conn = Get-12cCosmosConnection -DatabaseName $DatabaseName -ContainerName $ContainerName
    if (-not $PartitionKey) { $PartitionKey = $Id }

    $accountEndpoint = ($conn.ConnectionString -split 'AccountEndpoint=')[1] -split ';' | Select-Object -First 1
    $accountKey = ($conn.ConnectionString -split 'AccountKey=')[1] -split ';' | Select-Object -First 1

    $resourcePath = "dbs/$DatabaseName/colls/$ContainerName/docs/$Id"
    $date = [DateTime]::UtcNow.ToString("r")
    $verb = "DELETE"
    $stringToSign = "$($verb.ToLower())`ndocs`n$resourcePath`n$($date.ToLower())`n`n"

    $hmacSha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacSha.Key = [Convert]::FromBase64String($accountKey)
    $hash = $hmacSha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign))
    $sig = [Convert]::ToBase64String($hash)
    $auth = "type=master&ver=1.0&sig=$sig"

    $headers = @{
        Authorization     = [System.Web.HttpUtility]::UrlEncode($auth)
        "x-ms-date"       = $date
        "x-ms-version"    = "2018-12-31"
        "x-ms-documentdb-partitionkey" = '["' + $PartitionKey + '"]'
    }

    $uri = "$($accountEndpoint.TrimEnd('/'))/$resourcePath"
    return Invoke-RestMethod -Uri $uri -Headers $headers -Method DELETE
}

# --- TEST EXECUTION BELOW ---

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

$configurationModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\Configuration\ConfigurationPackage\ConfigurationPackage.psd1'
$orchestratorAzureModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\OrchestratorAzure\OrchestratorAzure.psd1'
$envConfigPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\..\environments\dev.json'

Write-Host "Starting CosmosDB integration tests..." -ForegroundColor Cyan
Import-Module -Name $configurationModulePath -Force
Import-Module -Name $orchestratorAzureModulePath -Force
Initialize-12Configuration $envConfigPath
Connect-12Azure

$connection = Get-12cCosmosConnection -DatabaseName "OrchestratorDb" -ContainerName "Items"
Write-Host "✓ Connected to CosmosDB: $($connection.AccountName)" -ForegroundColor Green

$testId = "test-item-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$testItem = @{
    id = $testId
    partitionKey = $testId
    name = "Test"
    description = "Created by integration test"
    timestamp = (Get-Date).ToString("o")
}

$result = Set-12cItem -Item $testItem -DatabaseName "OrchestratorDb" -ContainerName "Items"
Write-Host "✓ Item upserted: $testId" -ForegroundColor Green

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
