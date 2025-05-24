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
Write-Host "Current object ID: $currentObjectId" -ForegroundColor Yellow

# Import Get-ScriptRoot function from CoreUpdaterPackage\functions.ps1
. "c:\dev\12C\OrchestratorPsh\CoreUpdaterPackage\functions.ps1"

# Define root directory for the project
$projectRootPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-Not $projectRootPath) {
    $projectRootPath = "c:\dev\12C\OrchestratorPsh"
}

# Ensure paths for sync-parameters.ps1 and main.parameters.json are correct
$syncParametersPath = Join-Path -Path $PSScriptRoot -ChildPath "sync-parameters.ps1"
$parameterFilePath = Join-Path -Path $PSScriptRoot -ChildPath "main.parameters.json"

Write-Host "Using sync-parameters.ps1 to synchronize parameters..." -ForegroundColor Yellow
# Call sync-parameters with Force parameter to update main.parameters.json from dev.json
# The script already checks if environments/dev.json exists
& $syncParametersPath -Force

# Add a check to ensure main.parameters.json exists
if (-Not (Test-Path -Path $parameterFilePath)) {
    Write-Host "Error: Parameter file not found at $parameterFilePath" -ForegroundColor Red
    exit 1
}

# Get the parameter file to update GitHub repo URL and ObjectID
$parameterContent = Get-Content -Path $parameterFilePath -Raw | ConvertFrom-Json

# Update non-environment specific values that sync-parameters doesn't handle
if (-not $currentObjectId) {
    Write-Host "Error: ownerObjectId (currentObjectId) could not be determined. Please ensure you are signed in with 'Connect-AzAccount' and have the correct context." -ForegroundColor Red
    exit 1
}
$parameterContent.parameters.ownerObjectId.value = $currentObjectId
Write-Host "Updated ownerObjectId in parameters file to: $currentObjectId" -ForegroundColor Green

$parameterContent.parameters.githubRepoUrl.value = $env:GITHUB_REPO_URL



# Remove unused variable warning
$createEmptyPat = $false

# Check if the PAT secret exists in Key Vault - we'll only create an empty PAT if it doesn't exist
$keyVaultName = $parameterContent.parameters.keyVaultName.value
$createEmptyPat = $false

# Check if the resource group and Key Vault already exist and if we should create an empty PAT secrets
$resourceGroupExists = Get-AzResourceGroup -Name $parameterContent.parameters.resourceGroupName.value -ErrorAction SilentlyContinue
if ($resourceGroupExists) {
    # Check if Key Vault exists
    $keyVaultExists = Get-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $parameterContent.parameters.resourceGroupName.value -ErrorAction SilentlyContinue
    
    if ($keyVaultExists) {
        # Try to get the PAT secret
        try {
            $patSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name "PAT" -ErrorAction SilentlyContinue
            if ($patSecret) {
                Write-Host "PAT secret already exists in Key Vault. Will not create an empty one." -ForegroundColor Yellow
                $createEmptyPat = $false
            } else {
                Write-Host "PAT secret does not exist in Key Vault. Will create an empty one." -ForegroundColor Yellow
                $createEmptyPat = $true
            }
        }
        catch {
            # If we get an error (likely due to permissions), we'll assume PAT doesn't exist
            Write-Host "Could not check if PAT secret exists. Will create an empty one." -ForegroundColor Yellow
            $createEmptyPat = $true
        }
    } else {
        # If Key Vault doesn't exist, we're doing initial deployment and should create PAT
        Write-Host "Key Vault doesn't exist yet. Will create an empty PAT secret during deployment." -ForegroundColor Yellow
        $createEmptyPat = $true
    }
} else {
    # If resource group doesn't exist, we're doing initial deployment and should create PAT
    Write-Host "Resource Group doesn't exist yet. Will create an empty PAT secret during deployment." -ForegroundColor Yellow
    $createEmptyPat = $true
}

# Add the createEmptyPat parameter to the parameter file
if (-not $parameterContent.parameters.createEmptyPat) {
    $parameterContent.parameters | Add-Member -MemberType NoteProperty -Name 'createEmptyPat' -Value @{value = $createEmptyPat}
} else {
    $parameterContent.parameters.createEmptyPat.value = $createEmptyPat
}

# Save the updated parameter file
$parameterContent | ConvertTo-Json -Depth 10 | Set-Content -Path $parameterFilePath

# Set deployment values
$location = $parameterContent.parameters.location.value
Write-Host "Using Location: $location from parameter file"
$deploymentName = "orchestratorPsh-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')"

# Show deployment parameters summary
Write-Host "Deploying with the following parameters:" -ForegroundColor Green
Write-Host "  Resource Group: $($parameterContent.parameters.resourceGroupName.value)`n  Key Vault: $($parameterContent.parameters.keyVaultName.value)`n  Location: $($parameterContent.parameters.location.value)`n  GitHub Repo URL: $env:GITHUB_REPO_URL`n  Tenant ID: $($parameterContent.parameters.tenantId.value)`n  Subscription ID: $($parameterContent.parameters.subscriptionId.value)`n  Object ID: $($parameterContent.parameters.ownerObjectId.value)`n  App Object ID: $($parameterContent.parameters.appObjectId.value)`n  Create Empty PAT: $($parameterContent.parameters.createEmptyPat.value)" -ForegroundColor Cyan

# Deploy the Bicep template at subscription level
Write-Host "Deploying Bicep template at subscription level..." -ForegroundColor Green
$templateFilePath = Join-Path -Path $PSScriptRoot -ChildPath "main.bicep"
Write-Host "Using template file: $templateFilePath" -ForegroundColor Green
Write-Host "Using parameter file: $parameterFilePath" -ForegroundColor Green
New-AzSubscriptionDeployment `
    -Name $deploymentName `
    -Location $location `
    -TemplateFile $templateFilePath `
    -TemplateParameterFile $parameterFilePath `
    -githubRepoUrl $env:GITHUB_REPO_URL `
    -createEmptyPat $createEmptyPat `
    -Verbose

# Get and display the deployment outputs
$subscriptionDeployment = Get-AzSubscriptionDeployment -Name $deploymentName -ErrorAction SilentlyContinue
if ($subscriptionDeployment) {
    Write-Host -ForegroundColor Magenta "Outputs: "
    $subscriptionDeployment.Outputs | Out-Host
}

Write-Host "Deployment completed."
