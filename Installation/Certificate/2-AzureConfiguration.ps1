# Azure App Registration with Certificate Authentication Setup Script

# Prerequisites: 
# - PowerShell 7.0 or later
# - Az PowerShell module installed (Install-Module -Name Az)
# - Azure CLI installed (for alternative commands)

# Define paths at top of script
$configPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\..\environments\dev.json'
$moduleRoot = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\Modules\OrchestratorCommon'

# Moved variable declarations to the top of the script for better organization

# Parameters - customize these values
$config = Get-Content -Path $configPath | ConvertFrom-Json

# Import OrchestratorCommon module for Azure operations
Import-Module $moduleRoot -Force


$certPassword = Read-Host -Prompt "Enter certificate password" 
$securePassword = ConvertTo-SecureString -String $certPassword -Force -AsPlainText

$certPath = ".\$($config.CertName).pfx"
$certCerPath = ".\$($config.CertName).cer"
$certThumbprint = $null

# Step 1: Sign in to Azure
Connect-AzAccount

# Step 2: Create a self-signed certificate
Write-Host "Creating self-signed certificate..." -ForegroundColor Green

# Create self-signed certificate
$cert = New-SelfSignedCertificate -CertStoreLocation Cert:\CurrentUser\My `
    -Subject "CN=$($config.CertName)" `
    -KeySpec Signature `
    -NotAfter (Get-Date).AddYears($($config.expiryYears)) `
    -KeyExportPolicy Exportable `
    -KeyAlgorithm RSA `
    -KeyLength 2048

$certThumbprint = $cert.Thumbprint

# Export PFX (private key) file
Export-PfxCertificate -Cert "Cert:\CurrentUser\My\$certThumbprint" -FilePath $certPath -Password $securePassword
Write-Host "PFX certificate exported to $certPath" -ForegroundColor Green

# Export CER (public key) file
Export-Certificate -Cert "Cert:\CurrentUser\My\$certThumbprint" -FilePath $certCerPath -Type CERT
Write-Host "CER certificate exported to $certCerPath" -ForegroundColor Green
Write-Host "Certificate thumbprint: $certThumbprint" -ForegroundColor Yellow

# Step 3: Register an app in Azure AD
Write-Host "Creating Azure AD app registration..." -ForegroundColor Green

# Get current context for tenant ID
Set-AzContext -SubscriptionId $($config.SubscriptionId)
$context = Get-AzContext
$tenantId = $context.Tenant.Id

# Create the Azure AD application
$app = New-AzADApplication -DisplayName $($config.AppName)
$clientId = $app.AppId
Write-Host "Azure AD application created with client ID: $clientId" -ForegroundColor Green

# Create a service principal for the application
$sp = New-AzADServicePrincipal -ApplicationId $clientId
$spObjectId = $sp.Id
Write-Host "Service principal created with object ID: $spObjectId" -ForegroundColor Green


# Get the Object ID using the Get-ServicePrincipalObjectId function from OrchestratorCommon module
$confirmedObjectId = Get-ServicePrincipalObjectId -AppId $clientId -TenantId $tenantId -SubscriptionId $($config.SubscriptionId)
Write-Host -ForegroundColor Magenta "Update the environment config with the following Object ID: $confirmedObjectId" -ForegroundColor Green





# Step 4: Upload the certificate to the app registration
Write-Host "Uploading certificate to app registration..." -ForegroundColor Green
# Read the .cer file content
$certData = [System.Convert]::ToBase64String(([System.IO.File]::ReadAllBytes((ls $certCerPath).FullName)))

# Add error handling and ensure proper date validation for certificate upload
try {
    # Ensure StartDate and EndDate are properly set
    $startDate = (Get-Date).ToUniversalTime()
    $endDate = $startDate.AddYears($($config.expiryYears)).ToUniversalTime()

    if ($endDate -le $startDate) {
        throw "EndDate must be later than StartDate."
    }

    # Add certificate to app registration
    New-AzADAppCredential -ApplicationId $clientId `
        -CertValue $certData `
        -StartDate $startDate `
        -EndDate $endDate

    Write-Host "Certificate uploaded successfully to app registration" -ForegroundColor Green
} catch {
    Write-Host "An error occurred while uploading the certificate: $_" -ForegroundColor Red
    throw
}

# ASSIGN PERMISSIONS

# Step 5: Provide access to the app to secrets in Azure Key Vault
Write-Host "Providing access to the app for secrets in Azure Key Vault..." -ForegroundColor Green

# Set access policy for the service principal using Object ID
# Method 1: Use the Object ID directly
Set-AzKeyVaultAccessPolicy -VaultName $($config.KeyVaultName) -ResourceGroupName $($config.ResourceGroupName) -ObjectId $spObjectId -PermissionsToSecrets get,list
Write-Host "Access policy set for the service principal on Key Vault using Object ID" -ForegroundColor Green

# Note: The legacy approach using ServicePrincipalName (which uses appId) is shown below:
# Set-AzKeyVaultAccessPolicy -VaultName $($config.KeyVaultName) -ResourceGroupName $($config.ResourceGroupName) -ServicePrincipalName $clientId -PermissionsToSecrets get,list

# Step 6: Upload the .cer and .pfx files to Azure Key Vault using Import-AzKeyVaultCertificate
Write-Host "Uploading certificate files to Azure Key Vault..." -ForegroundColor Green
Import-AzKeyVaultCertificate -VaultName $($config.KeyVaultName) -Name $($config.CertName) -FilePath $certPath -Password $securePassword



# Summary
Write-Host "`n======== SETUP COMPLETE ========" -ForegroundColor Green
Write-Host "App Name: $($config.AppName)" -ForegroundColor Cyan
Write-Host "Client ID: $clientId" -ForegroundColor Cyan
Write-Host "Tenant ID: $tenantId" -ForegroundColor Cyan
Write-Host "Certificate Thumbprint: $certThumbprint" -ForegroundColor Cyan
Write-Host "Certificate Path (PFX): $certPath" -ForegroundColor Cyan
Write-Host "Certificate Path (CER): $certCerPath" -ForegroundColor Cyan
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Create a Key Vault and set access policies for this service principal" -ForegroundColor Yellow
Write-Host "2. Use the certificate to authenticate your application to Azure" -ForegroundColor Yellow
Write-Host "3. Store these values securely for future use" -ForegroundColor Yellow

# Example usage instructions
Write-Host "`nExample code to use this certificate for authentication:" -ForegroundColor Magenta
Write-Host @"
# Connect to Azure using certificate authentication
Connect-AzAccount -ServicePrincipal -CertificateThumbprint "$certThumbprint" -ApplicationId "$clientId" -TenantId "$tenantId"

# OR with certificate file
# `$certPassword = ConvertTo-SecureString -String "$certPassword" -Force -AsPlainText
# `$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("$certPath", `$certPassword)
# Connect-AzAccount -ServicePrincipal -CertificateThumbprint `$cert.Thumbprint -ApplicationId "$clientId" -TenantId "$tenantId"
"@ -ForegroundColor Magenta

# Update dev.json file with the new values
Write-Host "`nUpdating dev.json file with new values..." -ForegroundColor Yellow
$config.appId = $clientId
$config.certThumbprint = $certThumbprint
$config.servicePrincipalObjectId = $spObjectId

# Save the updated config
$config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
Write-Host "dev.json updated successfully with appId, certThumbprint and servicePrincipalObjectId" -ForegroundColor Green



