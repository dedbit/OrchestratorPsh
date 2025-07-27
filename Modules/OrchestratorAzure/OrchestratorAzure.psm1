# OrchestratorAzure.psm1
# Module for Azure-related functions used across OrchestratorPsh scripts

# Import Packaging module for Ensure-NuGetProvider dependency
$packagingModulePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\Packaging\Packaging.psd1'
Import-Module $packagingModulePath -Force

# Function to connect to Azure with the specified tenant and subscription
function Connect-12Azure {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]$ForceNewLogin,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipSubscriptionCheck
    )
    
    try {
        # Retrieve TenantId and SubscriptionId from $global:12cConfig
        if (-not $global:12cConfig) {
            throw "Global configuration variable '12cConfig' is not set. Please initialize it first."
        }

        $TenantId = $global:12cConfig.TenantId
        $SubscriptionId = $global:12cConfig.SubscriptionId

        # Check if already connected to Azure with correct tenant and subscription
        $context = Get-AzContext
        $needsLogin = $ForceNewLogin -or (-not $context) -or 
                      ($context.Tenant.Id -ne $TenantId) -or 
                      (
                        -not $SkipSubscriptionCheck -and 
                        ($context.Subscription.Id -ne $SubscriptionId)
                      )

        if ($needsLogin) {
            Write-Host "Connecting to Azure with Tenant ID: $TenantId and Subscription ID: $SubscriptionId" -ForegroundColor Cyan

            if ($ForceNewLogin) {
                # Force disconnect if already connected
                Disconnect-AzAccount -ErrorAction SilentlyContinue
                Clear-AzContext -Force -ErrorAction SilentlyContinue
            }

            Connect-AzAccount -TenantId $TenantId -SubscriptionId $SubscriptionId -ErrorAction Stop
        } else {
            Write-Host "Already connected to Azure with appropriate Tenant and Subscription" -ForegroundColor Green
        }

        return $true
    }
    catch {
        Write-Error "Error connecting to Azure: $($_.Exception.Message)"
        return $false
    }
}

# Function to connect to Azure using a certificate
function Connect-12AzureWithCertificate {
    [CmdletBinding()]
    param ()

    try {
        if (-not $global:12cConfig) {
            throw "Global configuration variable '12cConfig' is not set. Please initialize it first."
        }
        $TenantId = $global:12cConfig.TenantId
        $CertificateThumbprint = $global:12cConfig.certThumbprint
        $ApplicationId = $global:12cConfig.appId

        Write-Host "Connecting to Azure using certificate authentication..." -ForegroundColor Cyan

        # Check if Az module is available, install if needed
        if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
            Write-Host "Az.Accounts module is not available. Installing..." -ForegroundColor Yellow
            try {
                # Ensure NuGet provider is available first
                Ensure-NuGetProvider
                Install-Module -Name Az.Accounts -Force -Scope CurrentUser -AllowClobber -Repository PSGallery
                Write-Host "Az.Accounts module installed successfully." -ForegroundColor Green
            } catch {
                throw "Failed to install Az.Accounts module: $($_.Exception.Message)"
            }
        }

        # Import Az.Accounts if not already loaded
        if (-not (Get-Module -Name Az.Accounts)) {
            try {
                Import-Module Az.Accounts -Force
                Write-Host "Az.Accounts module imported successfully." -ForegroundColor Green
            } catch {
                throw "Failed to import Az.Accounts module: $($_.Exception.Message)"
            }
        }

        $connection = Connect-AzAccount -ServicePrincipal -CertificateThumbprint $CertificateThumbprint -ApplicationId $ApplicationId -TenantId $TenantId

        Write-Host "Successfully connected to Azure using certificate authentication." -ForegroundColor Green
        return $connection
    } catch {
        Write-Error "Error connecting to Azure using certificate: $($_.Exception.Message)"
        throw
    }
}

# Function to retrieve secrets from Azure Key Vault using global configuration
function Get-12cKeyVaultSecret {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SecretName
    )

    try {
        if (-not $global:12cConfig) {
            throw "Global configuration variable '12cConfig' is not set. Please initialize it first."
        }

        $KeyVaultName = $global:12cConfig.keyVaultName
        if ([string]::IsNullOrWhiteSpace($KeyVaultName)) {
            throw "KeyVaultName is not configured in global configuration."
        }

        # Ensure we have the necessary Az modules
        $requiredModules = @('Az.Accounts', 'Az.KeyVault')
        foreach ($moduleName in $requiredModules) {
            if (-not (Get-Module -ListAvailable -Name $moduleName)) {
                Write-Host "Installing $moduleName module..." -ForegroundColor Yellow
                try {
                    # Ensure NuGet provider is available first
                    Ensure-NuGetProvider
                    Install-Module -Name $moduleName -Force -Scope CurrentUser -AllowClobber -Repository PSGallery
                    Write-Host "$moduleName module installed successfully." -ForegroundColor Green
                } catch {
                    throw "Failed to install $moduleName module: $($_.Exception.Message)"
                }
            }
            if (-not (Get-Module -Name $moduleName)) {
                try {
                    Import-Module $moduleName -Force
                    Write-Host "$moduleName module imported successfully." -ForegroundColor Green
                } catch {
                    throw "Failed to import $moduleName module: $($_.Exception.Message)"
                }
            }
        }

        # Retrieve the secret from Azure Key Vault
        $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -ErrorAction Stop
        
        # Extract the secret value properly - handle different possible formats
        try {
            # First try the newer way (SecretValue as SecureString)
            if ($secret.SecretValue -is [System.Security.SecureString]) {
                $secretValueText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret.SecretValue))
            }
            # Then try direct text (older versions)
            elseif ($null -ne $secret.SecretValueText) {
                $secretValueText = $secret.SecretValueText
            }
            else {
                throw "Could not extract secret value using known methods."
            }
        }
        catch {
            Write-Error "Error extracting secret value: $($_.Exception.Message)"
            throw
        }
        
        # Validate the extracted secret
        if ([string]::IsNullOrWhiteSpace($secretValueText)) {
            throw "Retrieved secret is null or empty."
        }

        Write-Host "Secret '$SecretName' retrieved successfully from Key Vault." -ForegroundColor Green
        return $secretValueText
        
    } catch {
        Write-Error "Error retrieving secret '$SecretName' from Key Vault: $($_.Exception.Message)"
        throw
    }
}

# Function to convert an Application ID to Object ID (Service Principal ID)
function Get-ServicePrincipalObjectId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppId,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $false)]
        [switch]$ForceNewLogin
    )
    
    try {
        # Connect to Azure using the existing Connect-12Azure function
        # $connected = Connect-12Azure -TenantId $TenantId -SubscriptionId $SubscriptionId -ForceNewLogin:$ForceNewLogin
        $connected = Connect-12Azure -ForceNewLogin:$ForceNewLogin
        if (-not $connected) {
            throw "Failed to connect to Azure"
        }
        
        # Look up the service principal by Application ID
        Write-Verbose "Looking up object ID for Application ID: $AppId"
        $servicePrincipal = Get-AzADServicePrincipal -ApplicationId $AppId -ErrorAction Stop
        
        if ($null -eq $servicePrincipal) {
            throw "No service principal found for Application ID: $AppId"
        }
        
        Write-Verbose "Found service principal with Object ID: $($servicePrincipal.Id)"
        return $servicePrincipal.Id
    }
    catch {
        Write-Error "Error in Get-ServicePrincipalObjectId: $($_.Exception.Message)"
        throw
    }
}

# Function to set a secret in Key Vault
function Set-12cKeyVaultSecret {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SecretName,
        
        [Parameter(Mandatory = $true)]
        [string]$SecretValue,
        
        [Parameter(Mandatory = $false)]
        [switch]$ForceNewLogin
    )
    
    try {
        # Ensure we have a connection to Azure
        $connected = Connect-12Azure -ForceNewLogin:$ForceNewLogin
        if (-not $connected) {
            throw "Failed to connect to Azure"
        }
        
        # Get Key Vault name from configuration
        if (-not $global:12cConfig) {
            throw "Global configuration variable '12cConfig' is not set. Please initialize it first."
        }
        
        $keyVaultName = $global:12cConfig.keyVaultName
        if ([string]::IsNullOrEmpty($keyVaultName)) {
            throw "Key Vault name not found in configuration"
        }
        
        # Convert the secret value to SecureString
        $secureSecretValue = ConvertTo-SecureString $SecretValue -AsPlainText -Force
        
        # Set the secret (this will create or update as needed)
        Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $SecretName -SecretValue $secureSecretValue -ErrorAction Stop
        
        Write-Host "Secret '$SecretName' has been set in Key Vault '$keyVaultName'." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Error setting secret '$SecretName' in Key Vault: $($_.Exception.Message)"
        return $false
    }
}

# Export the functions
Export-ModuleMember -Function Get-12cKeyVaultSecret, Connect-12Azure, Get-ServicePrincipalObjectId, Connect-12AzureWithCertificate, Set-12cKeyVaultSecret
