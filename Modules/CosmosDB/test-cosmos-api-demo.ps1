# test-cosmos-api-demo.ps1
# Demo script showing how to use the CosmosDB module functions

# Define paths at top of script
$modulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'CosmosDBPackage\CosmosDBPackage.psm1'
$configurationModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\Configuration\ConfigurationPackage\ConfigurationPackage.psm1'

Write-Host "CosmosDB Module API Demo" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan

# Import required modules
try {
    Import-Module -Name $configurationModulePath -Force
    Import-Module -Name $modulePath -Force
    Write-Host "✓ Modules imported successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to import modules: $($_.Exception.Message)"
    exit 1
}

# Initialize configuration
try {
    Initialize-12Configuration
    Write-Host "✓ Configuration initialized" -ForegroundColor Green
} catch {
    Write-Error "Failed to initialize configuration: $($_.Exception.Message)"
    exit 1
}

Write-Host "`nAPI Usage Examples:" -ForegroundColor Yellow

# Example 1: Show Get-12cItem syntax
Write-Host "`n1. Get an item by ID:" -ForegroundColor White
Write-Host "   Get-12cItem -Id 'user123'" -ForegroundColor Gray
Write-Host "   Get-12cItem -Id 'user123' -PartitionKey 'users' -DatabaseName 'MyDB' -ContainerName 'Users'" -ForegroundColor Gray

# Example 2: Show Set-12cItem syntax
Write-Host "`n2. Set/Update an item:" -ForegroundColor White
Write-Host "   `$item = @{ id = 'user123'; name = 'John Doe'; email = 'john@example.com' }" -ForegroundColor Gray
Write-Host "   Set-12cItem -Item `$item" -ForegroundColor Gray
Write-Host "   Set-12cItem -Item `$item -DatabaseName 'MyDB' -ContainerName 'Users'" -ForegroundColor Gray

# Example 3: Show Get-12cCosmosConnection syntax
Write-Host "`n3. Get connection details:" -ForegroundColor White
Write-Host "   `$connection = Get-12cCosmosConnection" -ForegroundColor Gray
Write-Host "   `$connection = Get-12cCosmosConnection -DatabaseName 'MyDB' -ContainerName 'Users'" -ForegroundColor Gray

# Show configuration details
Write-Host "`nCurrent Configuration:" -ForegroundColor Yellow
Write-Host "  Cosmos Account: $($Global:12cConfig.cosmosDbAccountName)" -ForegroundColor White
Write-Host "  Key Vault: $($Global:12cConfig.keyVaultName)" -ForegroundColor White

# Show function parameters
Write-Host "`nFunction Details:" -ForegroundColor Yellow

$functions = @('Get-12cItem', 'Set-12cItem', 'Get-12cCosmosConnection')
foreach ($functionName in $functions) {
    $cmd = Get-Command $functionName -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host "`n$functionName parameters:" -ForegroundColor White
        $cmd.Parameters.Keys | Where-Object { $_ -notin @('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable') } | ForEach-Object {
            $param = $cmd.Parameters[$_]
            $mandatory = if ($param.Attributes.Mandatory) { " (Required)" } else { " (Optional)" }
            Write-Host "  - $($_)$mandatory" -ForegroundColor Gray
        }
    }
}

Write-Host "`nNote: Full functionality requires Azure connectivity and CosmosDB setup with connection string in Key Vault." -ForegroundColor Yellow
Write-Host "Demo completed successfully!" -ForegroundColor Green