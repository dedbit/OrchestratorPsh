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




# Only check for Key Vault existence for post-deployment secret logic
$keyVaultName = $parameterContent.parameters.keyVaultName.value
$resourceGroupExists = Get-AzResourceGroup -Name $parameterContent.parameters.resourceGroupName.value -ErrorAction SilentlyContinue
if ($resourceGroupExists) {
    $keyVaultExists = Get-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $parameterContent.parameters.resourceGroupName.value -ErrorAction SilentlyContinue
} else {
    $keyVaultExists = $null
}

# Set deployment values
$location = $parameterContent.parameters.location.value
Write-Host "Using Location: $location from parameter file"
$deploymentName = "orchestratorPsh-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')"

# Show deployment parameters summary
Write-Host "Deploying with the following parameters:" -ForegroundColor Green
Write-Host "  Resource Group: $($parameterContent.parameters.resourceGroupName.value)`n  Key Vault: $($parameterContent.parameters.keyVaultName.value)`n  Location: $($parameterContent.parameters.location.value)`n  GitHub Repo URL: $env:GITHUB_REPO_URL`n  Tenant ID: $($parameterContent.parameters.tenantId.value)`n  Subscription ID: $($parameterContent.parameters.subscriptionId.value)`n  Object ID: $($parameterContent.parameters.ownerObjectId.value)`n  App Object ID: $($parameterContent.parameters.appObjectId.value)" -ForegroundColor Cyan

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
    -Verbose


# Get and display the deployment outputs
$subscriptionDeployment = Get-AzSubscriptionDeployment -Name $deploymentName -ErrorAction SilentlyContinue
if ($subscriptionDeployment) {
    Write-Host -ForegroundColor Magenta "Outputs: "
    $subscriptionDeployment.Outputs | Out-Host
}

Write-Host "Deployment completed."

# --- Post-deployment: Set PAT secret only if not present ---
$patSecretName = "PAT"
$initialSecretValue = "INITIAL_PAT_VALUE_TO_BE_REPLACED_MANUALLY" # Placeholder value

# Check if Key Vault exists (determined earlier in the script)
if ($keyVaultExists) {
    try {
        # Attempt to retrieve the secret
        $patSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $patSecretName -ErrorAction SilentlyContinue

        if ($null -eq $patSecret) {
            # Secret does not exist, so create it
            Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $patSecretName -SecretValue (ConvertTo-SecureString $initialSecretValue -AsPlainText -Force)
            Write-Host "PAT secret '$patSecretName' was not found and has been created with an initial value in Key Vault '$keyVaultName'. Please update it manually with the correct PAT." -ForegroundColor Green
        } else {
            # Secret already exists
            Write-Host "PAT secret '$patSecretName' already exists in Key Vault '$keyVaultName'. No action taken." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error checking or setting PAT secret '$patSecretName' in Key Vault '$keyVaultName': $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "Key Vault '$keyVaultName' not found. Cannot check or create PAT secret." -ForegroundColor Red
}
