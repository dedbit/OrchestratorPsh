cd C:\dev\12C\OrchestratorPsh\messaging
Import-Module ..\Modules\Configuration\ConfigurationPackage.psd1
Import-Module ..\Modules\OrchestratorAzure\OrchestratorAzure.psd1
Initialize-12Configuration ..\environments\dev.json
Connect-12Azure


$PersonalAccessToken = Get-PATFromKeyVault -KeyVaultName $12cConfig.keyVaultName -SecretName "PAT" -TenantId $12cConfig.tenantId -SubscriptionId $12cConfig.subscriptionId
$ArtifactsFeedUrl = $12cConfig.artifactsFeedUrl
# $PersonalAccessToken = $PersonalAccessToken
$SecurePAT = ConvertTo-SecureString $PersonalAccessToken -AsPlainText -Force
$Credential = New-Object PSCredential('AzureDevOps', $SecurePAT)


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


Increment-MessagingModuleVersion



# Unregister-PSRepository -Name 'OrchestratorPshRepo3'
$cred = New-Object System.Management.Automation.PSCredential("AzureDevOps", $securePAT)
Register-PSRepository -Name "OrchestratorPshRepo3" `
                      -SourceLocation $ArtifactsFeedUrl `
                      -PublishLocation $ArtifactsFeedUrl `
                      -InstallationPolicy Trusted `
                      -Credential $cred

#worked:
$Credential = New-Object PSCredential('AzureDevOps', $SecurePAT)
Register-PSRepository -Name 'OrchestratorPshRepo' `
-SourceLocation $ArtifactsFeedUrl `
-PublishLocation $ArtifactsFeedUrl `
-InstallationPolicy Trusted `
-Credential $Credential  



#Worked in past in win psh
Find-Module -Name 'Messaging*' -Repository 'OrchestratorPshRepo'
#Did not work in pwsh 5
Find-Module -Repository 'OrchestratorPshRepo'

# Unregister-PSRepository -Name 'OrchestratorPshRepo'
$ArtifactsFeedUrlV2 = 'https://pkgs.dev.azure.com/12c/Testprojects/_packaging/OrchestratorPsh/nuget/v2'
Register-PSRepository -Name 'OrchestratorPshRepo2' `
                      -SourceLocation $ArtifactsFeedUrlV2 `
                      -PublishLocation $ArtifactsFeedUrlV2 `
                      -InstallationPolicy Trusted `
                      -Credential $Credential

# Publish-Module -Path "..\Output\MessagingModule.1.0.17.nupkg" -Repository "OrchestratorPshRepo" -NuGetApiKey $SecurePAT
Publish-Module -Path "C:\dev\12C\OrchestratorPsh\messaging\MessagingModule\" -Repository "OrchestratorPshRepo" -NuGetApiKey $SecurePAT

#Install-Module -Name MessagingModule -RequiredVersion '1.0.14' -Repository 'OrchestratorPshRepo'
Find-Module -Repository 'OrchestratorPshRepo'
Find-Module -Name 'Messaging*' -Repository 'OrchestratorPshRepo'


# Windows powershell 5.1
Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
Install-Module MessagingModule
Install-Module MessagingModule -Repository OrchestratorPshRepo


## psh 7 using v2 feed worked. 
# Also works in pwsh 5.1
# had issues in session. But removing psrepository OrchestratorPshRepo22 and opening new terminal helped

$SecurePAT = ConvertTo-SecureString $PersonalAccessToken -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential('AzureDevOps', $SecurePAT)
Install-Module -Name MessagingModule -Repository 'OrchestratorPshRepo' -Credential $Cred


Unregister-PSRepository -Name 'OrchestratorPshRepo22'
# Unregister-PSRepository -Name  OrchestratorPshRepo
Get-PSRepository
# $RepoUrlV2 = "https://pkgs.dev.azure.com/12c/yourProject/_packaging/OrchestratorPshRepo/nuget/v2"
$ArtifactsFeedUrlV2 = 'https://pkgs.dev.azure.com/12c/Testprojects/_packaging/OrchestratorPsh/nuget/v2'
$ArtifactsFeedUrlV2
Register-PSRepository -Name 'OrchestratorPshRepo22' `
                      -SourceLocation $ArtifactsFeedUrlV2 `
                      -PublishLocation $ArtifactsFeedUrlV2 `
                      -InstallationPolicy Trusted `
                      -Credential $Cred

Publish-Module -Path "C:\dev\12C\OrchestratorPsh\messaging\MessagingModule\" -Repository "OrchestratorPshRepo22" -NuGetApiKey $SecurePAT


# Install module
Uninstall-Module MessagingModule
Install-Module -Name MessagingModule -Repository 'OrchestratorPshRepo22' -Credential $Cred -Force
Install-Module -Name MessagingModule -Scope AllUsers -Repository 'OrchestratorPshRepo22' -Credential $Cred
Get-InstalledModule MessagingModule |fl

# Import module
get-module MessagingModule
Import-Module MessagingModule
Get-Command -module MessagingModule
Remove-Module MessagingModule
