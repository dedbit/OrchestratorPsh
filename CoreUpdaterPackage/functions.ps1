function Get-ScriptRoot {
    if ($PSScriptRoot) {
        return $PSScriptRoot
    } else {
        return (Get-Location).Path
    }
}

function Ensure-12PsRepository {
    # Use Initialize-12Configuration to load config
    if (-not (Get-Command Initialize-12Configuration -ErrorAction SilentlyContinue)) {
        throw "Initialize-12Configuration is not available. Please import the ConfigurationPackage module."
    }
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

    $RepositoryName = 'OrchestratorPshRepo22'
    $SourceLocation = $ArtifactsFeedUrlV2
    $PublishLocation = $ArtifactsFeedUrlV2

    # Retrieve the PAT securely as in scripts.ps1
    $SecretName = "PAT"
    $PersonalAccessToken = Get-PATFromKeyVault -KeyVaultName $KeyVaultName -SecretName $SecretName -TenantId $TenantId -SubscriptionId $SubscriptionId
    $SecurePAT = ConvertTo-SecureString $PersonalAccessToken -AsPlainText -Force
    $Credential = New-Object PSCredential('AzureDevOps', $SecurePAT)

    $repo = Get-PSRepository -Name $RepositoryName -ErrorAction SilentlyContinue
    if ($null -eq $repo) {
        Write-Host "Registering PSRepository '$RepositoryName'..." -ForegroundColor Yellow
        Register-PSRepository -Name $RepositoryName `
            -SourceLocation $SourceLocation `
            -PublishLocation $PublishLocation `
            -InstallationPolicy Trusted `
            -Credential $Credential
        Write-Host "PSRepository '$RepositoryName' registered." -ForegroundColor Green
    } else {
        Write-Host "PSRepository '$RepositoryName' already exists." -ForegroundColor Green
    }
}
