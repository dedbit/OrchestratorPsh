function Get-ScriptRoot {
    if ($PSScriptRoot) {
        return $PSScriptRoot
    } else {
        return (Get-Location).Path
    }
}

function Ensure-12PsRepository {
    # Loads parameters from environment/config as in scripts.ps1
    # Load environment config to get KeyVaultName, TenantId, SubscriptionId, ArtifactsFeedUrlV2
    $envConfigPath = Join-Path -Path (Get-ScriptRoot) -ChildPath "..\environments\dev.json"
    if (Test-Path $envConfigPath) {
        $envConfig = Get-Content -Path $envConfigPath -Raw | ConvertFrom-Json
        $KeyVaultName = $envConfig.keyVaultName
        $TenantId = $envConfig.tenantId
        $SubscriptionId = $envConfig.subscriptionId
        $ArtifactsFeedUrlV2 = $envConfig.artifactsFeedUrlV2
    } else {
        throw "Could not find environment config at $envConfigPath."
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
