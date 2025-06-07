# test-module.ps1
# Script to test the OrchestratorAzure module functionality

# Define paths at top of script
$configModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\..\Modules\Configuration\ConfigurationPackage\ConfigurationPackage.psd1'
$orchestratorAzureModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\..\Modules\OrchestratorAzure\OrchestratorAzure.psd1'
$envConfigPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\..\environments\dev.json'

Import-Module $configModulePath
Import-Module $orchestratorAzureModulePath
Initialize-12Configuration $envConfigPath
Connect-12Azure

# Handle cases where $PSScriptRoot might be empty (when code is pasted into terminal)
$scriptRoot = if ($PSScriptRoot) { 
    $PSScriptRoot 
} else { 
    # Try to determine the location based on the current path
    $currentPath = Get-Location
    if ((Split-Path -Leaf $currentPath) -eq "OrchestratorAzure") {
        $currentPath.Path
    } elseif (Test-Path (Join-Path -Path $currentPath -ChildPath "Modules\OrchestratorAzure")) {
        Join-Path -Path $currentPath -ChildPath "Modules\OrchestratorAzure"
    } else {
        Write-Warning "Could not determine script location. Using current directory."
        $currentPath.Path
    }
}

# Import the module
$modulePath = Join-Path -Path $scriptRoot -ChildPath "OrchestratorAzure.psd1"
Import-Module -Name $modulePath -Force
Write-Host "OrchestratorAzure module imported successfully." -ForegroundColor Green

# Show available functions in the module
$moduleFunctions = Get-Command -Module OrchestratorAzure
Write-Host "Available functions in OrchestratorAzure module:" -ForegroundColor Cyan
$moduleFunctions | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Yellow }

# Test the functions if environment config is available
if (Test-Path $envConfigPath) {
    # Load environment config
    $envConfig = Get-Content -Path $envConfigPath -Raw | ConvertFrom-Json
    $KeyVaultName = $12cConfig.keyVaultName
    $TenantId = $12cConfig.tenantId
    $SubscriptionId = $12cConfig.subscriptionId
    
    Write-Host "Using Key Vault: $KeyVaultName" -ForegroundColor Cyan
    Write-Host "Using Tenant ID: $TenantId" -ForegroundColor Cyan
    Write-Host "Using Subscription ID: $SubscriptionId" -ForegroundColor Cyan
    
    # Test Connect-12Azure function
    Write-Host "`nTesting Connect-12Azure function..." -ForegroundColor Cyan
    $connected = Connect-12Azure #-TenantId $TenantId -SubscriptionId $SubscriptionId
    if ($connected) {
        Write-Host "Connection successful!" -ForegroundColor Green
    } else {
        Write-Host "Connection failed!" -ForegroundColor Red
    }
    
    # Test Get-PATFromKeyVault function
    Write-Host "`nTesting Get-PATFromKeyVault function..." -ForegroundColor Cyan
    try {
        $SecretName = "PAT"
        $PersonalAccessToken = Get-PATFromKeyVault -KeyVaultName $KeyVaultName -SecretName $SecretName -TenantId $TenantId -SubscriptionId $SubscriptionId
        
        if ($PersonalAccessToken) {
            $maskedValue = $PersonalAccessToken.Substring(0, [Math]::Min(4, $PersonalAccessToken.Length)) + "..."
            Write-Host "PAT retrieved successfully! Value (masked): $maskedValue" -ForegroundColor Green
            Write-Host "PAT length: $($PersonalAccessToken.Length) characters" -ForegroundColor Green
        } else {
            Write-Host "Failed to retrieve PAT or PAT is empty!" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Error testing Get-PATFromKeyVault: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "`nCould not find environment config at $envConfigPath. Skipping function test." -ForegroundColor Yellow
}

Write-Host "`nTest completed!" -ForegroundColor Green
