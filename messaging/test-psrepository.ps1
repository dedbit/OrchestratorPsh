function Increment-MessagingModuleVersion {
    # Use Get-PSCommandPath from ConfigurationPackage
    # $scriptRoot = Split-Path -Parent (Get-PSCommandPath)
    # $psd1Path = Join-Path -Path $scriptRoot -ChildPath 'MessagingModule\MessagingModule.psd1'
    # $content = Get-Content $psd1Path

    $psd1Path = 'MessagingModule\MessagingModule.psd1'
    $content = Get-Content $psd1Path
    
    $versionLineIndex = $content | Select-String -Pattern '^\s*ModuleVersion\s*=' | Select-Object -First 1 | ForEach-Object { $_.LineNumber - 1 }
    if ($null -eq $versionLineIndex) {
        Write-Error "ModuleVersion not found in $psd1Path"
        return
    }

    $versionLine = $content[$versionLineIndex]
    if ($versionLine -match "'(\d+)\.(\d+)\.(\d+)'") {
        $major = [int]$matches[1]
        $minor = [int]$matches[2]
        $patch = [int]$matches[3] + 1
        $newVersion = "'$major.$minor.$patch'"
        $content[$versionLineIndex] = $versionLine -replace "'\d+\.\d+\.\d+'", $newVersion
        Set-Content -Path $psd1Path -Value $content
        Write-Host "Incremented MessagingModule.psd1 version to $major.$minor.$patch"
    } else {
        Write-Error "Could not parse version in $psd1Path"
    }
}



function Test-UnregisterRegister-PSRepository {
    param(
        [string]$RepoName,
        [string]$FeedUrl,
        [pscredential]$Cred
    )
    Write-Host "Testing Unregister and Register for PSRepository: $RepoName"
    try {
        Unregister-PSRepository -Name $RepoName -ErrorAction SilentlyContinue
    } catch {}
    $existing = Get-PSRepository -Name $RepoName -ErrorAction SilentlyContinue
    if ($existing) {
        throw "Failed to unregister $RepoName"
    }
    Register-PSRepository -Name $RepoName -SourceLocation $FeedUrl -PublishLocation $FeedUrl -InstallationPolicy Trusted -Credential $Cred
    $registered = Get-PSRepository -Name $RepoName -ErrorAction SilentlyContinue
    if (-not $registered) {
        throw "Failed to register $RepoName"
    }
    Write-Host "Unregister/Register test passed for $RepoName"
}

function Test-InstallVerifyUninstall-Module {
    param(
        [string]$ModuleName,
        [string]$RepoName,
        [pscredential]$Cred
    )
    Write-Host "Testing Install, Verify, Uninstall for module: $ModuleName"
    try {
        Uninstall-Module $ModuleName -ErrorAction SilentlyContinue
    } catch {}
    Install-Module -Name $ModuleName -Repository $RepoName -Credential $Cred -Force
    $mod = Get-InstalledModule $ModuleName -ErrorAction SilentlyContinue
    if (-not $mod) {
        throw "Module $ModuleName failed to install from $RepoName"
    }
    Write-Host "Module $ModuleName installed successfully"
    Uninstall-Module $ModuleName -Force
    $mod2 = Get-InstalledModule $ModuleName -ErrorAction SilentlyContinue
    if ($mod2) {
        throw "Module $ModuleName failed to uninstall"
    }
    Write-Host "Module $ModuleName uninstalled successfully"
}

function Test-ImportVerifyRemove-Module {
    param(
        [string]$ModuleName
    )
    Write-Host "Testing Import, Verify, Remove for module: $ModuleName"
    Import-Module $ModuleName -Force
    $imported = Get-Module $ModuleName -ListAvailable
    if (-not $imported) {
        throw "Module $ModuleName not available after import"
    }
    $cmds = Get-Command -Module $ModuleName
    if (-not $cmds) {
        throw "No commands found in $ModuleName after import"
    }
    Write-Host "Module $ModuleName imported and commands found"
    Remove-Module $ModuleName -Force
    $stillLoaded = Get-Module $ModuleName
    if ($stillLoaded) {
        throw "Module $ModuleName failed to remove"
    }
    Write-Host "Module $ModuleName removed successfully"
}

function Get-MessagingModuleVersion {
    $psd1Path = 'MessagingModule/MessagingModule.psd1'
    $content = Get-Content $psd1Path
    $versionLine = $content | Where-Object { $_ -match '^\s*ModuleVersion\s*=' }
    if ($versionLine -match "'(\d+\.\d+\.\d+)'") {
        return $matches[1]
    }
    throw "Could not find version in $psd1Path"
}

function Run-PSRepositoryModuleTests {
    $repoName = 'OrchestratorPshRepo22'
    $feedUrl = 'https://pkgs.dev.azure.com/12c/Testprojects/_packaging/OrchestratorPsh/nuget/v2'
    $moduleName = 'MessagingModule'
    
    # Increment version and get new version
    Increment-MessagingModuleVersion
    $newVersion = Get-MessagingModuleVersion
    Write-Host "New MessagingModule version: $newVersion"

    # Unregister/register repo
    Test-UnregisterRegister-PSRepository -RepoName $repoName -FeedUrl $feedUrl -Cred $Credential

    # Publish module
    Publish-Module -Path "MessagingModule" -Repository $repoName -NuGetApiKey $SecurePAT
    Write-Host "Published $moduleName version $newVersion to $repoName"

    # Uninstall any existing version
    try { Uninstall-Module $moduleName -AllVersions -Force -ErrorAction SilentlyContinue } catch {}

    # Install and verify version
    Install-Module -Name $moduleName -Repository $repoName -Credential $Credential -Force
    $mod = Get-InstalledModule $moduleName -ErrorAction SilentlyContinue
    if (-not $mod) { throw "Module $moduleName failed to install from $repoName" }
    if ($mod.Version.ToString() -ne $newVersion) {
        throw "Installed version $($mod.Version) does not match expected $newVersion"
    }
    Write-Host "Module $moduleName version $newVersion installed successfully"

    # Remove for import test
    Uninstall-Module $moduleName -Force
    Install-Module -Name $moduleName -Repository $repoName -Credential $Credential -Force
    Test-ImportVerifyRemove-Module -ModuleName $moduleName
    Write-Host "All PSRepository and module tests completed successfully."
}


# filepath: c:\dev\12C\OrchestratorPsh\messaging\test-psrepository.ps1
# Test script for PSRepository and MessagingModule
Import-Module ..\Modules\Configuration\ConfigurationPackage.psd1
Import-Module ..\Modules\OrchestratorAzure\OrchestratorAzure.psd1
Initialize-12Configuration ..\environments\dev.json
Connect-12Azure

$PersonalAccessToken = Get-PATFromKeyVault -KeyVaultName $12cConfig.keyVaultName -SecretName "PAT" -TenantId $12cConfig.tenantId -SubscriptionId $12cConfig.subscriptionId
$ArtifactsFeedUrl = $12cConfig.artifactsFeedUrl
$SecurePAT = ConvertTo-SecureString $PersonalAccessToken -AsPlainText -Force
$Credential = New-Object PSCredential('AzureDevOps', $SecurePAT)


Run-PSRepositoryModuleTests



