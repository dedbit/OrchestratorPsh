# test-keyvault-fixed.ps1
# Script to test the Get-PATFromKeyVault function

# Import the Az module
Import-Module Az

# Function to retrieve a secret from Azure Key Vault
function Get-PATFromKeyVault {
    param (
        [string]$KeyVaultName,
        [string]$SecretName,
        [string]$TenantId,
        [string]$SubscriptionId,
        [switch]$ForceNewLogin
    )

    Write-Host "Testing Get-PATFromKeyVault function..." -ForegroundColor Cyan
    Write-Host "KeyVaultName: $KeyVaultName" -ForegroundColor Yellow
    Write-Host "SecretName: $SecretName" -ForegroundColor Yellow
    Write-Host "Force New Login: $($ForceNewLogin.IsPresent)" -ForegroundColor Yellow
    
    try {
        # Check if already connected to Azure with correct tenant and subscription
        $context = Get-AzContext
        $needsLogin = $ForceNewLogin -or (-not $context) -or 
                     ($context.Tenant.Id -ne $TenantId) -or 
                     ($context.Subscription.Id -ne $SubscriptionId)
        
        if ($needsLogin) {
            Write-Host "Connecting to Azure..." -ForegroundColor Cyan
            
            if ($ForceNewLogin) {
                # Force disconnect if already connected
                Write-Host "Forcing disconnection from any existing sessions..." -ForegroundColor Yellow
                Disconnect-AzAccount -ErrorAction SilentlyContinue
                Clear-AzContext -Force -ErrorAction SilentlyContinue
            }
            
            # Try interactive login
            Connect-AzAccount -TenantId $TenantId -SubscriptionId $SubscriptionId -ErrorAction Stop
            
            # Get updated context
            $context = Get-AzContext
        } else {
            Write-Host "Already connected to Azure with appropriate Tenant and Subscription" -ForegroundColor Green
        }
        
        # Verify we are connected with the right context
        Write-Host "Connected as: $($context.Account.Id)" -ForegroundColor Green
        Write-Host "Tenant: $($context.Tenant.Id)" -ForegroundColor Green
        Write-Host "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -ForegroundColor Green

        # Retrieve the secret from Azure Key Vault
        Write-Host "Retrieving secret from Key Vault..." -ForegroundColor Cyan
        $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -ErrorAction Stop
        
        Write-Host "Secret retrieved successfully." -ForegroundColor Green
        Write-Host "Secret object type: $($secret.GetType().FullName)" -ForegroundColor Yellow
        Write-Host "Available properties:" -ForegroundColor Yellow
        $secret | Get-Member | Where-Object { $_.MemberType -eq "Property" } | ForEach-Object {
            Write-Host "  - $($_.Name)" -ForegroundColor Yellow
        }
          # Extract the secret value properly - handle different possible formats
        try {
            # First try the newer way (SecretValue as SecureString)
            if ($secret.SecretValue -is [System.Security.SecureString]) {
                $secretValueText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret.SecretValue))
                Write-Host "Secret value extracted via SecureString method." -ForegroundColor Green
            }
            # Then try direct text (older versions)
            elseif ($null -ne $secret.SecretValueText) {
                $secretValueText = $secret.SecretValueText
                Write-Host "Secret value extracted via SecretValueText property." -ForegroundColor Green
            }
            else {
                throw "Could not extract secret value using known methods."
            }
        }
        catch {
            Write-Host "Error extracting secret value: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
        
        Write-Host "Secret value extracted successfully." -ForegroundColor Green
          # Return just the first few characters of the secret for security
        if ($secretValueText -and $secretValueText.Length -gt 0) {
            $maskedValue = $secretValueText.Substring(0, [Math]::Min(4, $secretValueText.Length)) + "..."
            Write-Host "Secret value (masked): $maskedValue" -ForegroundColor Green
            Write-Host "Secret value length: $($secretValueText.Length) characters" -ForegroundColor Green
            return $secretValueText
        } else {
            Write-Host "Secret value is null or empty!" -ForegroundColor Red
            Write-Host "This likely means the PAT hasn't been set in the Key Vault yet." -ForegroundColor Yellow
            Write-Host "You can set it manually using: Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -SecretValue (ConvertTo-SecureString -String 'YOUR_PAT_VALUE' -AsPlainText -Force)" -ForegroundColor Yellow
            return $null
        }
    }
    catch {
        Write-Host "Error accessing Key Vault: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Get environment config
$envConfigPath = "..\environments\dev.json"
if (Test-Path $envConfigPath) {
    $envConfig = Get-Content -Path $envConfigPath -Raw | ConvertFrom-Json
    $KeyVaultName = $envConfig.keyVaultName
    $TenantId = $envConfig.tenantId
    $SubscriptionId = $envConfig.subscriptionId
    
    Write-Host "Environment configuration loaded successfully." -ForegroundColor Green
    Write-Host "Using Key Vault: $KeyVaultName" -ForegroundColor Cyan
    Write-Host "Using Tenant ID: $TenantId" -ForegroundColor Cyan
    Write-Host "Using Subscription ID: $SubscriptionId" -ForegroundColor Cyan
} else {
    Write-Error "Could not find environment config at $envConfigPath. Aborting test."
    exit 1
}

# Test the function
Write-Host "Testing PAT retrieval from Key Vault..." -ForegroundColor Cyan
$SecretName = "PAT"  # The secret name to retrieve
$PersonalAccessToken = Get-PATFromKeyVault -KeyVaultName $KeyVaultName -SecretName $SecretName -TenantId $TenantId -SubscriptionId $SubscriptionId

if ($PersonalAccessToken) {
    Write-Host "PAT retrieved successfully!" -ForegroundColor Green
} else {
    Write-Host "Failed to retrieve PAT." -ForegroundColor Red
}
