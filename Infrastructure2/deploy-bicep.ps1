# deploy-bicep.ps1
# This script deploys the Bicep template
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

# Load environment configuration for tenant, subscription IDs, key vault name, and resource group name
$envConfigPath = "..\environments\dev.json"
$tenantId = ""
$subscriptionId = ""
$keyVaultName = ""
$resourceGroupName = ""

if (Test-Path $envConfigPath) {
    $envConfig = Get-Content -Path $envConfigPath -Raw | ConvertFrom-Json
    $tenantId = $envConfig.tenantId
    $subscriptionId = $envConfig.subscriptionId
    $keyVaultName = $envConfig.keyVaultName
    $resourceGroupName = $envConfig.resourceGroupName
    Write-Host "Loaded configuration from environments/dev.json:"
    Write-Host "  Tenant ID: $tenantId"
    Write-Host "  Subscription ID: $subscriptionId"
    Write-Host "  Key Vault Name: $keyVaultName"
    Write-Host "  Resource Group Name: $resourceGroupName"
} else {
    Write-Warning "Could not find environment config at $envConfigPath. Will continue without environment configuration values."
}

# Update the Bicep parameter file with current user's object ID, GitHub repo URL, and IDs from environment config
$parameterFilePath = "main.parameters.json"
$parameterContent = Get-Content -Path $parameterFilePath -Raw | ConvertFrom-Json
$parameterContent.parameters.objectId.value = $currentObjectId
$parameterContent.parameters.githubRepoUrl.value = $env:GITHUB_REPO_URL

# Update tenant, subscription IDs, key vault name, and resource group name from environment config
if (-not [string]::IsNullOrEmpty($tenantId)) {
    $parameterContent.parameters.tenantId.value = $tenantId
}
if (-not [string]::IsNullOrEmpty($subscriptionId)) {
    $parameterContent.parameters.subscriptionId.value = $subscriptionId
}
if (-not [string]::IsNullOrEmpty($keyVaultName)) {
    $parameterContent.parameters.keyVaultName.value = $keyVaultName
    Write-Host "Using Key Vault Name: $keyVaultName from environments/dev.json"
}
if (-not [string]::IsNullOrEmpty($resourceGroupName)) {
    $parameterContent.parameters.resourceGroupName.value = $resourceGroupName
    Write-Host "Using Resource Group Name: $resourceGroupName from environments/dev.json"
}

$parameterContent | ConvertTo-Json -Depth 10 | Set-Content -Path $parameterFilePath

# Set deployment values
$location = "West Europe"
$deploymentName = "orchestratorPsh-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')"

# Show deployment parameters summary
Write-Host "Deploying with the following parameters:" -ForegroundColor Green
Write-Host "  Resource Group: $($parameterContent.parameters.resourceGroupName.value)" -ForegroundColor Cyan
Write-Host "  Key Vault: $($parameterContent.parameters.keyVaultName.value)" -ForegroundColor Cyan
Write-Host "  GitHub Repo URL: $env:GITHUB_REPO_URL" -ForegroundColor Cyan
Write-Host "  Tenant ID: $($parameterContent.parameters.tenantId.value)" -ForegroundColor Cyan
Write-Host "  Subscription ID: $($parameterContent.parameters.subscriptionId.value)" -ForegroundColor Cyan
Write-Host "  Object ID: $currentObjectId" -ForegroundColor Cyan

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
