# Load external function files
$scriptRoot = $PSScriptRoot ? $PSScriptRoot : (Get-Location).Path
. (Join-Path $scriptRoot 'ConfigurationFunctions.ps1')
. (Join-Path $scriptRoot 'OrchestratorAzureFunctions.ps1')
. (Join-Path $scriptRoot 'PackagingFunctions.ps1')

function Get-ScriptRoot {
    if ($PSScriptRoot) {
        return $PSScriptRoot
    } else {
        return (Get-Location).Path
    }
}

function Ensure-12PsRepository {
    # Use Initialize-12Configuration to load config
    if (-not $global:12cConfig) {
        Initialize-12Configuration
    }
    if (-not $global:12cConfig) {
        throw "12cConfig is not set after Initialize-12Configuration."
    }
    $KeyVaultName = $global:12cConfig.keyVaultName
    $TenantId = $global:12cConfig.tenantId
    $SubscriptionId = $global:12cConfig.subscriptionId
    $ArtifactsFeedUrlV2 = $global:12cConfig.artifactsFeedUrlV2

    if ([string]::IsNullOrWhiteSpace($KeyVaultName)) {
        Write-Error "KeyVaultName is null or empty in 12cConfig: $($global:12cConfig | ConvertTo-Json -Compress)"
        throw "KeyVaultName is null or empty. Cannot continue."
    }

    if ([string]::IsNullOrWhiteSpace($ArtifactsFeedUrlV2)) {
        Write-Error "ArtifactsFeedUrlV2 is null or empty in 12cConfig: $($global:12cConfig | ConvertTo-Json -Compress)"
        throw "ArtifactsFeedUrlV2 is null or empty. Cannot continue."
    }

    $RepositoryName = 'OrchestratorPshRepo22'
    $SourceLocation = $ArtifactsFeedUrlV2
    $PublishLocation = $ArtifactsFeedUrlV2

    # Retrieve the PAT securely as in scripts.ps1
    $SecretName = "PAT"
    Write-Host "Retrieving Personal Access Token from Key Vault..." -ForegroundColor Cyan
    try {
        $PersonalAccessToken = Get-12cKeyVaultSecret -SecretName $SecretName
        if ([string]::IsNullOrWhiteSpace($PersonalAccessToken)) {
            throw "Retrieved PAT is null or empty"
        }
        Write-Host "Personal Access Token retrieved successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed to retrieve PAT from Key Vault: $($_.Exception.Message)"
        throw
    }

    $SecurePAT = ConvertTo-SecureString $PersonalAccessToken -AsPlainText -Force
    $Credential = New-Object PSCredential('AzureDevOps', $SecurePAT)

    # Store credentials globally for use in Install-Module operations
    $global:12cPSRepositoryCredential = $Credential

    # Test network connectivity to the artifacts feed using PAT for authentication
    Write-Host "Testing connectivity to artifacts feed: $ArtifactsFeedUrlV2" -ForegroundColor Cyan
    try {
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PersonalAccessToken"))
        $headers = @{ Authorization = "Basic $base64AuthInfo" }
        Invoke-WebRequest -Uri $ArtifactsFeedUrlV2 -Method Get -Headers $headers -TimeoutSec 10 -MaximumRedirection 0 -ErrorAction Stop | Out-Null
        Write-Host "Successfully connected to artifacts feed." -ForegroundColor Green
    } catch {
        Write-Warning "Could not connect to artifacts feed: $($_.Exception.Message)"
        Write-Host "This may cause issues with package installation. Check network connectivity, proxy settings, and PAT permissions." -ForegroundColor Yellow
    }

    $repo = Get-PSRepository -Name $RepositoryName -ErrorAction SilentlyContinue
    if ($null -eq $repo) {
        Write-Host "Registering PSRepository '$RepositoryName'..." -ForegroundColor Yellow
        try {
            Register-PSRepository -Name $RepositoryName `
                -SourceLocation $SourceLocation `
                -PublishLocation $PublishLocation `
                -InstallationPolicy Trusted `
                -Credential $Credential
            Write-Host "PSRepository '$RepositoryName' registered successfully." -ForegroundColor Green
        } catch {
            Write-Error "Failed to register PSRepository '$RepositoryName': $($_.Exception.Message)"
            throw
        }
    } else {
        Write-Host "PSRepository '$RepositoryName' already exists." -ForegroundColor Green
        
        # Verify the repository configuration
        if ($repo.SourceLocation -ne $SourceLocation) {
            Write-Host "Repository source location mismatch. Updating..." -ForegroundColor Yellow
            try {
                Unregister-PSRepository -Name $RepositoryName
                Register-PSRepository -Name $RepositoryName `
                    -SourceLocation $SourceLocation `
                    -PublishLocation $PublishLocation `
                    -InstallationPolicy Trusted `
                    -Credential $Credential
                Write-Host "PSRepository '$RepositoryName' updated successfully." -ForegroundColor Green
            } catch {
                Write-Error "Failed to update PSRepository '$RepositoryName': $($_.Exception.Message)"
                throw
            }
        }
    }

    # Test repository access
    Write-Host "Testing repository access..." -ForegroundColor Cyan
    try {
        if ($global:12cPSRepositoryCredential) {
            $testModules = Find-Module -Repository $RepositoryName -Credential $global:12cPSRepositoryCredential -ErrorAction Stop | Select-Object -First 1
        } else {
            $testModules = Find-Module -Repository $RepositoryName -ErrorAction Stop | Select-Object -First 1
        }
        if ($testModules) {
            Write-Host "Repository access test successful." -ForegroundColor Green
        } else {
            Write-Warning "Repository access test returned no modules. This may be normal if no modules are published."
        }
    } catch {
        Write-Error "Failed to access repository '$RepositoryName': $($_.Exception.Message)"
        Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
        Write-Host "1. Verify network connectivity to $ArtifactsFeedUrlV2" -ForegroundColor Yellow
        Write-Host "2. Check if Personal Access Token has correct permissions" -ForegroundColor Yellow
        Write-Host "3. Verify the artifacts feed URL is correct" -ForegroundColor Yellow
        Write-Host "4. Try running: Get-PSRepository -Name '$RepositoryName'" -ForegroundColor Yellow
        throw
    }
}
