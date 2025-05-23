# OrchestratorCommon.psm1
# Module for common functions used across OrchestratorPsh scripts

# Function to connect to Azure with the specified tenant and subscription
function Connect-ToAzure {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $false)]
        [switch]$ForceNewLogin
    )
    
    try {
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

# Function to retrieve the Personal Access Token (PAT) from Azure Key Vault
function Get-PATFromKeyVault {
    param (
        [string]$KeyVaultName,
        [string]$SecretName,
        [string]$TenantId,
        [string]$SubscriptionId,
        [switch]$ForceNewLogin
    )

    try {
        # Connect to Azure using the extracted connection function
        $connected = Connect-ToAzure -TenantId $TenantId -SubscriptionId $SubscriptionId -ForceNewLogin:$ForceNewLogin
        if (-not $connected) {
            throw "Failed to connect to Azure"
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
        if ([string]::IsNullOrEmpty($secretValueText)) {
            Write-Warning "Retrieved PAT is null or empty. Please check the Key Vault secret."
        }
        
        return $secretValueText
    }
    catch {
        Write-Error "Error in Get-PATFromKeyVault: $($_.Exception.Message)"
        throw
    }
}

# Export the functions
Export-ModuleMember -Function Get-PATFromKeyVault, Connect-ToAzure
