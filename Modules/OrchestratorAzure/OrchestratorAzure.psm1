# OrchestratorAzure.psm1
# Module for Azure-related functions used across OrchestratorPsh scripts

# Function to connect to Azure with the specified tenant and subscription
function Connect-12Azure {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]$ForceNewLogin
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
                      ($context.Subscription.Id -ne $SubscriptionId)

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

        $connection = Connect-AzAccount -ServicePrincipal -CertificateThumbprint $12cConfig.certThumbprint -ApplicationId $12cConfig.AppId -TenantId $12cConfig.tenantId

        Write-Host "Successfully connected to Azure using certificate authentication." -ForegroundColor Green
        return $connection
    } catch {
        Write-Error "Error connecting to Azure using certificate: $($_.Exception.Message)"
        throw
    }
}

# Function to retrieve a secret from Azure Key Vault (generalized)
function Get-SecretFromKeyVault {
    param (
        [string]$KeyVaultName,
        [string]$SecretName,
        [string]$TenantId,
        [string]$SubscriptionId,
        [switch]$ForceNewLogin
    )
    try {
        $connected = Connect-12Azure -ForceNewLogin:$ForceNewLogin
        if (-not $connected) {
            throw "Failed to connect to Azure"
        }
        $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -ErrorAction Stop
        try {
            if ($secret.SecretValue -is [System.Security.SecureString]) {
                $secretValueText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret.SecretValue))
            } elseif ($null -ne $secret.SecretValueText) {
                $secretValueText = $secret.SecretValueText
            } else {
                throw "Could not extract secret value using known methods."
            }
        } catch {
            Write-Error "Error extracting secret value: $($_.Exception.Message)"
            throw
        }
        if ([string]::IsNullOrEmpty($secretValueText)) {
            Write-Warning "Retrieved secret is null or empty. Please check the Key Vault secret."
        }
        return $secretValueText
    } catch {
        Write-Error "Error in Get-SecretFromKeyVault: $($_.Exception.Message)"
        throw
    }
}

# Wrapper for backward compatibility
function Get-PATFromKeyVault {
    param (
        [string]$KeyVaultName,
        [string]$SecretName,
        [string]$TenantId,
        [string]$SubscriptionId,
        [switch]$ForceNewLogin
    )
    return Get-SecretFromKeyVault -KeyVaultName $KeyVaultName -SecretName $SecretName -TenantId $TenantId -SubscriptionId $SubscriptionId -ForceNewLogin:$ForceNewLogin
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

# Export the functions
Export-ModuleMember -Function Get-PATFromKeyVault, Connect-12Azure, Get-ServicePrincipalObjectId, Connect-12AzureWithCertificate
