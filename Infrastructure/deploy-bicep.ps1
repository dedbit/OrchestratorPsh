# deploy-bicep.ps1
# This script deploys the Bicep template using parameters synchronized from environments/dev.json
param(
    [string]$GithubRepoUrl = ""
)

# Get the GitHub repository URL from git configuration if not provided as parameter
if ([string]::IsNullOrEmpty($GithubRepoUrl)) {
    $repoUrl = git config --get remote.origin.url
    $env:GITHUB_REPO_URL = "$($repoUrl)"
} else {
    $env:GITHUB_REPO_URL = $GithubRepoUrl
}
Write-Host "Using GitHub repo URL: $env:GITHUB_REPO_URL"

# Get the current user's context for Key Vault access policy
$currentUser = Get-AzADUser -SignedIn
$currentObjectId = $currentUser.Id

Write-Host "Using sync-parameters.ps1 to synchronize parameters..." -ForegroundColor Yellow
# Call sync-parameters with Force parameter to update main.parameters.json from dev.json
# The script already checks if environments/dev.json exists
& ".\sync-parameters.ps1" -Force

# Get the parameter file to update GitHub repo URL and ObjectID
$parameterFilePath = "main.parameters.json"
$parameterContent = Get-Content -Path $parameterFilePath -Raw | ConvertFrom-Json

# Update non-environment specific values that sync-parameters doesn't handle
$parameterContent.parameters.objectId.value = $currentObjectId
$parameterContent.parameters.githubRepoUrl.value = $env:GITHUB_REPO_URL

# Save the updated parameter file
$parameterContent | ConvertTo-Json -Depth 10 | Set-Content -Path $parameterFilePath

# Set deployment values
$location = $parameterContent.parameters.location.value
Write-Host "Using Location: $location from parameter file"
$deploymentName = "orchestratorPsh-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')"

# Show deployment parameters summary
Write-Host "Deploying with the following parameters:" -ForegroundColor Green
Write-Host "  Resource Group: $($parameterContent.parameters.resourceGroupName.value)" -ForegroundColor Cyan
Write-Host "  Key Vault: $($parameterContent.parameters.keyVaultName.value)" -ForegroundColor Cyan
Write-Host "  Location: $($parameterContent.parameters.location.value)" -ForegroundColor Cyan
Write-Host "  GitHub Repo URL: $env:GITHUB_REPO_URL" -ForegroundColor Cyan
Write-Host "  Tenant ID: $($parameterContent.parameters.tenantId.value)" -ForegroundColor Cyan
Write-Host "  Subscription ID: $($parameterContent.parameters.subscriptionId.value)" -ForegroundColor Cyan
Write-Host "  Object ID: $currentObjectId" -ForegroundColor Cyan
Write-Host "  App ID: $($parameterContent.parameters.appId.value)" -ForegroundColor Cyan

# Deploy the Bicep template at subscription level
Write-Host "Deploying Bicep template at subscription level..." -ForegroundColor Green
New-AzSubscriptionDeployment `
    -Name $deploymentName `
    -Location $location `
    -TemplateFile "main.bicep" `
    -TemplateParameterFile $parameterFilePath `
    -githubRepoUrl $env:GITHUB_REPO_URL `
    -Verbose

# Get and display the deployment outputs
$subscriptionDeployment = Get-AzSubscriptionDeployment -Name $deploymentName -ErrorAction SilentlyContinue
if ($subscriptionDeployment) {
    Write-Host -ForegroundColor Magenta "Outputs: "
    $subscriptionDeployment.Outputs | Out-Host
}

Write-Host "Deployment completed."
