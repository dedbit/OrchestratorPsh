# PublishPackagesToKeyVault.ps1 - Reads packages.json and uploads it to KeyVault as "Packages" secret
# This script reads the local packages.json file and stores its contents in Azure Key Vault
# for use by the update scripts, providing centralized package management.

# Define paths at top of script
$functionsPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'Functions\functions.ps1'
$configPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'config.json'
$packagesJsonPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'packages.json'

# Load functions
. $functionsPath

# Initialize configuration from local config file
Initialize-12Configuration $configPath
Connect-12Azure

Write-Host "Publishing packages.json to Key Vault..." -ForegroundColor Cyan

# Validate packages.json exists
if (-not (Test-Path $packagesJsonPath)) {
    Write-Error "Could not find packages.json at $packagesJsonPath. Aborting script."
    exit 1
}

# Load and validate packages.json content
try {
    $packagesContent = Get-Content -Path $packagesJsonPath -Raw
    $packagesList = @($packagesContent | ConvertFrom-Json)
    Write-Host "Found $($packagesList.Count) packages in packages.json:" -ForegroundColor Green
    foreach ($pkg in $packagesList) {
        Write-Host "  - $pkg" -ForegroundColor Gray
    }
} catch {
    Write-Error "Failed to load or parse packages.json: $($_.Exception.Message)"
    exit 1
}

# Upload packages.json content to Key Vault as "Packages" secret
$secretName = "Packages"
try {
    Write-Host "Uploading packages list to Key Vault secret '$secretName'..." -ForegroundColor Yellow
    
    # Use the new Set-12cKeyVaultSecret function
    Set-12cKeyVaultSecret -SecretName $secretName -SecretValue $packagesContent
    
    Write-Host "✓ Packages list successfully uploaded to Key Vault secret '$secretName'" -ForegroundColor Green
    
    # Verify the upload by reading it back using the new function
    Write-Host "Verifying upload..." -ForegroundColor Yellow
    try {
        $verifyContent = Get-12cKeyVaultSecret -SecretName $secretName
        if ($verifyContent) {
            Write-Host "✓ Verification successful - secret '$secretName' exists in Key Vault" -ForegroundColor Green
        } else {
            Write-Warning "! Verification failed - could not retrieve secret after upload"
        }
    } catch {
        Write-Warning "! Verification failed - could not retrieve secret after upload: $($_.Exception.Message)"
    }
    
} catch {
    Write-Error "Failed to upload packages list to Key Vault: $($_.Exception.Message)"
    exit 1
}

Write-Host "`nPackages successfully published to Key Vault!" -ForegroundColor Green
Write-Host "The update scripts can now retrieve package lists from Key Vault secret '$secretName'" -ForegroundColor Cyan