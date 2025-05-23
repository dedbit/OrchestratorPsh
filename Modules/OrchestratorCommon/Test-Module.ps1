# Test-Module.ps1
# Script to test the OrchestratorCommon wrapper module functionality

# Verify OrchestratorAzure module exists
$azureModulePath = Join-Path -Path $PSScriptRoot -ChildPath "..\OrchestratorAzure\OrchestratorAzure.psd1"
if (-not (Test-Path $azureModulePath)) {
    Write-Error "OrchestratorAzure module not found at $azureModulePath. This is required by OrchestratorCommon."
    exit 1
}
else {
    Write-Host "OrchestratorAzure module found at $azureModulePath." -ForegroundColor Green
}

# Import the OrchestratorCommon module (which should load OrchestratorAzure)
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath "OrchestratorCommon.psd1"
Import-Module -Name $modulePath -Force
Write-Host "OrchestratorCommon module imported successfully." -ForegroundColor Green

# Show available functions in the OrchestratorCommon module
# These should match the functions from OrchestratorAzure
$moduleFunctions = Get-Command -Module OrchestratorCommon
Write-Host "Available functions in OrchestratorCommon module:" -ForegroundColor Cyan
$moduleFunctions | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Yellow }

# Verify OrchestratorAzure was loaded and check its functions
$azureModuleFunctions = Get-Command -Module OrchestratorAzure
if ($azureModuleFunctions) {
    Write-Host "OrchestratorAzure module was successfully loaded by OrchestratorCommon.`nFunctions in OrchestratorAzure module:`n$($azureModuleFunctions | ForEach-Object { "  - $($_.Name)" })" -ForegroundColor Green
} else {
    Write-Warning "OrchestratorAzure module was not loaded properly."
}

# Test the functions if environment config is available
$envConfigPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\environments\dev.json"
if (Test-Path $envConfigPath) {
    # Load environment config
    $envConfig = Get-Content -Path $envConfigPath -Raw | ConvertFrom-Json
    $KeyVaultName = $envConfig.keyVaultName
    $TenantId = $envConfig.tenantId
    $SubscriptionId = $envConfig.subscriptionId
    
    Write-Host "Using Key Vault: $KeyVaultName`nUsing Tenant ID: $TenantId`nUsing Subscription ID: $SubscriptionId`n`nTesting Connect-ToAzure function..." -ForegroundColor Cyan
    
    # Skip the interactive login part in test mode
    Write-Host "INFO: Skipping interactive Azure connection test to avoid login prompt." -ForegroundColor Yellow
    Write-Host "Connection test skipped." -ForegroundColor Yellow
    
    <# Comment out the actual connection test to avoid interactive prompts
    $connected = Connect-ToAzure -TenantId $TenantId -SubscriptionId $SubscriptionId
    if ($connected) {
        Write-Host "Connection successful!" -ForegroundColor Green
    } else {
        Write-Host "Connection failed!" -ForegroundColor Red
    }
    #>
    
    # Skip Get-PATFromKeyVault test which would also trigger authentication
    Write-Host "`nINFO: Skipping Get-PATFromKeyVault test to avoid login prompt." -ForegroundColor Yellow
    
    <# Comment out the actual KeyVault test to avoid interactive prompts
    # Test Get-PATFromKeyVault function
    Write-Host "`nTesting Get-PATFromKeyVault function..." -ForegroundColor Cyan
    try {
        $SecretName = "PAT"
        $PersonalAccessToken = Get-PATFromKeyVault -KeyVaultName $KeyVaultName -SecretName $SecretName -TenantId $TenantId -SubscriptionId $SubscriptionId
        
        if ($PersonalAccessToken) {
            $maskedValue = $PersonalAccessToken.Substring(0, [Math]::Min(4, $PersonalAccessToken.Length)) + "..."
            Write-Host "PAT retrieved successfully! Value (masked): $maskedValue" -ForegroundColor Green
            Write-Host "PAT length: $($PersonalAccessToken.Length) characters" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Error testing Get-PATFromKeyVault: $($_.Exception.Message)" -ForegroundColor Red
    }
    #>
} else {
    Write-Host "`nCould not find environment config at $envConfigPath. Skipping function test." -ForegroundColor Yellow
}

Write-Host "`nTest completed!" -ForegroundColor Green
