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

# Update the Bicep parameter file with current user's object ID and GitHub repo URL
$parameterFilePath = "main.parameters.json"
$parameterContent = Get-Content -Path $parameterFilePath -Raw | ConvertFrom-Json
$parameterContent.parameters.objectId.value = $currentObjectId
$parameterContent.parameters.githubRepoUrl.value = $env:GITHUB_REPO_URL
$parameterContent | ConvertTo-Json -Depth 10 | Set-Content -Path $parameterFilePath

# Set deployment values
$resourceGroupName = "orchestratorPsh2-dev-rg"
$location = "West Europe"

# Check if resource group exists, if not create it
$rgExists = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if (-not $rgExists) {
    New-AzResourceGroup -Name $resourceGroupName -Location $location
    Write-Host "Resource group '$resourceGroupName' created."
}
else {
    Write-Host "Resource group '$resourceGroupName' already exists."
}

# Deploy the Bicep template
Write-Host "Deploying Bicep template..."
New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile "main.bicep" `
    -TemplateParameterFile $parameterFilePath `
    -githubRepoUrl $env:GITHUB_REPO_URL `
    -Mode Incremental `
    -Verbose

# Get and display the deployment outputs
$deploymentOutputs = Get-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName | Where-Object { $_.DeploymentName -like "main-*" } | Select-Object -First 1 -ExpandProperty Outputs

Write-Host -ForegroundColor Magenta "Outputs: "
$deploymentOutputs | Out-Host

Write-Host "Deployment completed."
