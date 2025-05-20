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

# Load environment configuration for tenant and subscription IDs
$envConfigPath = "..\environments\dev.json"
$tenantId = ""
$subscriptionId = ""

if (Test-Path $envConfigPath) {
    $envConfig = Get-Content -Path $envConfigPath -Raw | ConvertFrom-Json
    $tenantId = $envConfig.tenantId
    $subscriptionId = $envConfig.subscriptionId
} else {
    Write-Warning "Could not find environment config at $envConfigPath. Will continue without tenant and subscription IDs."
}

# Update the Bicep parameter file with current user's object ID, GitHub repo URL, and IDs from environment config
$parameterFilePath = "main.parameters.json"
$parameterContent = Get-Content -Path $parameterFilePath -Raw | ConvertFrom-Json
$parameterContent.parameters.objectId.value = $currentObjectId
$parameterContent.parameters.githubRepoUrl.value = $env:GITHUB_REPO_URL

# Update tenant and subscription IDs from environment config
if (-not [string]::IsNullOrEmpty($tenantId)) {
    $parameterContent.parameters.tenantId.value = $tenantId
}
if (-not [string]::IsNullOrEmpty($subscriptionId)) {
    $parameterContent.parameters.subscriptionId.value = $subscriptionId
}

$parameterContent | ConvertTo-Json -Depth 10 | Set-Content -Path $parameterFilePath

# Set deployment values
$location = "West Europe"
$deploymentName = "orchestratorPsh-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')"

# Deploy the Bicep template at subscription level
Write-Host "Deploying Bicep template at subscription level..."
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
