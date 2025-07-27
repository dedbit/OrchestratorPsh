# deploy-bicep.ps1
# This script deploys the Bicep template using parameters synchronized from environments/dev.json
param(
    [string]$GithubRepoUrl = ""
)

function Convert-DeploymentOutputs {
    param(
        [Parameter(Mandatory = $true)]
        $DeploymentOutputs
    )
    $outputTypeName = $DeploymentOutputs.GetType().Name
    if ($outputTypeName -eq "JObject" -or $DeploymentOutputs.GetType().FullName -contains "Newtonsoft.Json.Linq.JObject") {
        Write-Host "Converting JObject to PowerShell object..." -ForegroundColor Yellow
        $DeploymentOutputs = $DeploymentOutputs.ToString() | ConvertFrom-Json
    } elseif ($DeploymentOutputs -is [string]) {
        Write-Host "Converting JSON string to PowerShell object..." -ForegroundColor Yellow
        $DeploymentOutputs = $DeploymentOutputs | ConvertFrom-Json
    }
    return $DeploymentOutputs
}

function Get-DeploymentOutputValue {
    param(
        [Parameter(Mandatory = $true)]
        $DeploymentOutputs,
        [Parameter(Mandatory = $true)]
        [string]$PropertyName
    )
    $value = $DeploymentOutputs.$PropertyName
    if ($value -is [Newtonsoft.Json.Linq.JValue]) {
        return $value.Value
    } else {
        return $value
    }
}

function Ensure-KeyVaultSecret {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VaultName,
        [Parameter(Mandatory = $true)]
        [string]$SecretName,
        [Parameter(Mandatory = $true)]
        [string]$InitialValue
    )
    try {
        $secret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -ErrorAction SilentlyContinue
        if ($null -eq $secret) {
            Set-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -SecretValue (ConvertTo-SecureString $InitialValue -AsPlainText -Force)
            Write-Host "PAT secret '$SecretName' was not found and has been created with an initial value in Key Vault '$VaultName'. Please update it manually with the correct PAT." -ForegroundColor Green
        } else {
            Write-Host "PAT secret '$SecretName' already exists in Key Vault '$VaultName'. No action taken." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error checking or setting PAT secret '$SecretName' in Key Vault '$VaultName': $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Define paths at top of script
$scriptRoot = $PSScriptRoot ? $PSScriptRoot : (Get-Location).Path
$functionsPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\CoreUpdaterPackage\Functions\functions.ps1'
$syncParametersPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'sync-parameters.ps1'
$parameterFilePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'main.parameters.json'
$templateFilePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) 'main.bicep'

# Import required modules
$orchestratorAzurePath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\Modules\OrchestratorAzure\OrchestratorAzure.psm1'
$configurationPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..\Modules\Configuration\ConfigurationPackage\ConfigurationPackage.psm1'

Import-Module $orchestratorAzurePath -Force
Import-Module $configurationPath -Force

# Initialize configuration
Initialize-12Configuration

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
. $functionsPath

# Define root directory for the project
$projectRootPath = Split-Path -Parent (Split-Path -Parent $scriptRoot)
if (-Not $projectRootPath) {
    $projectRootPath = Join-Path ($PSScriptRoot ? $PSScriptRoot : (Get-Location).Path) '..'
}

# Ensure paths for sync-parameters.ps1 and main.parameters.json are correct

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
    Ensure-KeyVaultSecret -VaultName $keyVaultName -SecretName $patSecretName -InitialValue $initialSecretValue
} else {
    Write-Host "Key Vault '$keyVaultName' not found. Cannot check or create PAT secret." -ForegroundColor Red
}

# --- Post-deployment: Set Cosmos DB connection string secret ---
try {
    # Get the Cosmos DB connection string from deployment outputs
    $deploymentOutputs = $subscriptionDeployment.Outputs.deploymentOutputs.Value
    $deploymentOutputs = Convert-DeploymentOutputs $deploymentOutputs
    $cosmosDbAccountName = Get-DeploymentOutputValue $deploymentOutputs 'cosmosDbAccountName'
    $resourceGroupName = Get-DeploymentOutputValue $deploymentOutputs 'resourceGroupName'
    Write-Host "Getting connection string for Cosmos DB account: $cosmosDbAccountName in resource group: $resourceGroupName" -ForegroundColor Yellow
    # Get the primary connection string
    $cosmosDbKeys = Invoke-AzResourceAction -Action listConnectionStrings -ResourceType "Microsoft.DocumentDB/databaseAccounts" -ResourceGroupName $resourceGroupName -ResourceName $cosmosDbAccountName -Force
    $cosmosDbConnectionString = $cosmosDbKeys.connectionStrings[0].connectionString
    # Use the new function to set the secret
    Set-12cKeyVaultSecret -SecretName "CosmosDbConnectionString" -SecretValue $cosmosDbConnectionString
    Write-Host "Cosmos DB connection string has been stored in Key Vault." -ForegroundColor Green
} catch {
    Write-Host "Error setting Cosmos DB connection string secret: $($_.Exception.Message)" -ForegroundColor Red
}


