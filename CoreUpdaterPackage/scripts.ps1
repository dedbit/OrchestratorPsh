Import-Module ..\Modules\Configuration\ConfigurationPackage.psd1
Import-Module ..\Modules\OrchestratorAzure\OrchestratorAzure.psd1
Initialize-12Configuration ..\environments\dev.json
Connect-12Azure


$PersonalAccessToken = Get-PATFromKeyVault -KeyVaultName $12cConfig.keyVaultName -SecretName "PAT" -TenantId $12cConfig.tenantId -SubscriptionId $12cConfig.subscriptionId
$ArtifactsFeedUrl = $12cConfig.artifactsFeedUrl
# $PersonalAccessToken = $PersonalAccessToken
$SecurePAT = ConvertTo-SecureString $PersonalAccessToken -AsPlainText -Force
$Credential = New-Object PSCredential('AzureDevOps', $SecurePAT)



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


## psh 7 using v2 feed worked
$SecurePAT = ConvertTo-SecureString $PersonalAccessToken -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential('AzureDevOps', $SecurePAT)
Install-Module -Name MessagingModule -Repository 'OrchestratorPshRepo' -Credential $Cred



$RepoUrlV2 = "https://pkgs.dev.azure.com/12c/yourProject/_packaging/OrchestratorPshRepo/nuget/v2"
$ArtifactsFeedUrlV2
Register-PSRepository -Name 'OrchestratorPshRepo22' `
                      -SourceLocation $ArtifactsFeedUrlV2 `
                      -PublishLocation $ArtifactsFeedUrlV2 `
                      -InstallationPolicy Trusted

Install-Module -Name MessagingModule -Repository 'OrchestratorPshRepo22' -Credential $Cred -Force
Install-Module -Name MessagingModule -Scope AllUsers
Get-InstalledModule MessagingModule

