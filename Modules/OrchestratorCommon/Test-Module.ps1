# Test-Module.ps1
# Script to test the OrchestratorCommon module functionality

# Import the module
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath "OrchestratorCommon.psd1"
Import-Module -Name $modulePath -Force
Write-Host "OrchestratorCommon module imported successfully." -ForegroundColor Green

# Show available functions in the module
$moduleFunctions = Get-Command -Module OrchestratorCommon
Write-Host "Available functions in OrchestratorCommon module:" -ForegroundColor Cyan
$moduleFunctions | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Yellow }

# Test the functions if environment config is available
$envConfigPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\environments\dev.json"
if (Test-Path $envConfigPath) {
    # Load environment config
    $envConfig = Get-Content -Path $envConfigPath -Raw | ConvertFrom-Json
    $KeyVaultName = $envConfig.keyVaultName
    $TenantId = $envConfig.tenantId
    $SubscriptionId = $envConfig.subscriptionId
    
    Write-Host "Using Key Vault: $KeyVaultName" -ForegroundColor Cyan
    Write-Host "Using Tenant ID: $TenantId" -ForegroundColor Cyan
    Write-Host "Using Subscription ID: $SubscriptionId" -ForegroundColor Cyan
    
    # Test Connect-ToAzure function
    Write-Host "`nTesting Connect-ToAzure function..." -ForegroundColor Cyan
    $connected = Connect-ToAzure -TenantId $TenantId -SubscriptionId $SubscriptionId
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
