# Terminate.ps1
# This script permanently deletes all resources created by the Bicep deployment
# including the resource group and removes Key Vault from the Azure recycle bin

# Parameters that can be overridden
param(
    [string]$ResourceGroupName = "orchestratorPsh2-dev-rg",
    [string]$KeyVaultName = "orchestrator2psh2-kv"
)

# Import required parameters from the parameters file if it exists
try {
    $parameterFilePath = "main.parameters.json"
    if (Test-Path $parameterFilePath) {
        $parameterContent = Get-Content -Path $parameterFilePath -Raw | ConvertFrom-Json
        # Override defaults with values from the parameter file if they exist
        if ($parameterContent.parameters.resourceGroupName) {
            $ResourceGroupName = $parameterContent.parameters.resourceGroupName.value
        }
        if ($parameterContent.parameters.keyVaultName) {
            $KeyVaultName = $parameterContent.parameters.keyVaultName.value
        }
    }
}
catch {
    Write-Warning "Could not read parameters from file. Using default values."
}

Write-Host "Starting termination process..." -ForegroundColor Yellow

# Connect to Azure if not already connected
$context = Get-AzContext
if (-not $context) {
    Write-Host "No Azure context found. Please sign in..." -ForegroundColor Cyan
    Connect-AzAccount -TenantId "6df08080-a31a-4efa-8c05-2373fc4515fc" -SubscriptionId "d3e92861-7740-4f9f-8cd2-bdfe8dd4bde3"
}

# Check if the resource group exists
$rgExists = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

if ($rgExists) {
    # First, check if Key Vault exists and remove it with purge protection
    Write-Host "Checking for Key Vault '$KeyVaultName'..." -ForegroundColor Cyan
    $keyVault = Get-AzKeyVault -ResourceGroupName $ResourceGroupName -VaultName $KeyVaultName -ErrorAction SilentlyContinue
    
    if ($keyVault) {
        Write-Host "Deleting Key Vault '$KeyVaultName'..." -ForegroundColor Cyan
        Remove-AzKeyVault -ResourceGroupName $ResourceGroupName -VaultName $KeyVaultName -Force
        
        # Wait for deletion to complete
        $retryCount = 0
        $maxRetries = 5
        $deleted = $false
        
        while (-not $deleted -and $retryCount -lt $maxRetries) {
            $retryCount++
            Start-Sleep -Seconds 10
            $kvCheck = Get-AzKeyVault -ResourceGroupName $ResourceGroupName -VaultName $KeyVaultName -ErrorAction SilentlyContinue
            if (-not $kvCheck) {
                $deleted = $true
            }
            else {
                Write-Host "Waiting for Key Vault deletion (attempt $retryCount of $maxRetries)..." -ForegroundColor Yellow
            }
        }
    }
    
    # Delete the resource group
    Write-Host "Deleting Resource Group '$ResourceGroupName'..." -ForegroundColor Cyan
    Remove-AzResourceGroup -Name $ResourceGroupName -Force
    
    # Wait for resource group deletion
    $retryCount = 0
    $maxRetries = 10
    $deleted = $false
    
    while (-not $deleted -and $retryCount -lt $maxRetries) {
        $retryCount++
        Start-Sleep -Seconds 10
        $rgCheck = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if (-not $rgCheck) {
            $deleted = $true
        }
        else {
            Write-Host "Waiting for Resource Group deletion (attempt $retryCount of $maxRetries)..." -ForegroundColor Yellow
        }
    }
}
else {
    Write-Host "Resource Group '$ResourceGroupName' does not exist." -ForegroundColor Yellow
}

# Check for the Key Vault in soft-deleted state
Write-Host "Checking for soft-deleted Key Vault '$KeyVaultName'..." -ForegroundColor Cyan
$deletedVaults = Get-AzKeyVault -InRemovedState

# Filter for our specific vault
$deletedVault = $deletedVaults | Where-Object { $_.VaultName -eq $KeyVaultName }

if ($deletedVault) {
    Write-Host "Found soft-deleted Key Vault. Purging permanently..." -ForegroundColor Cyan
    
    # When a Key Vault is soft-deleted, its location is still available
    $location = $deletedVault.Location
    
    # Purge the deleted vault
    Remove-AzKeyVault -VaultName $KeyVaultName -Location $location -InRemovedState -Force
    
    Write-Host "Key Vault '$KeyVaultName' has been permanently purged." -ForegroundColor Green
}
else {
    Write-Host "No soft-deleted Key Vault named '$KeyVaultName' was found." -ForegroundColor Yellow
}

# Final status
if ($deleted) {
    Write-Host "Resource Group '$ResourceGroupName' and all its resources have been successfully deleted." -ForegroundColor Green
}
else {
    Write-Host "Resource Group deletion may be still in progress. Please check the Azure portal." -ForegroundColor Yellow
}

Write-Host "Termination process completed." -ForegroundColor Green
