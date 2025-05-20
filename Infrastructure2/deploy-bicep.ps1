# deploy-bicep.ps1
# This script deploys the Bicep template

# Get the current user's context for Key Vault access policy
$currentUser = Get-AzADUser -SignedIn
$currentObjectId = $currentUser.Id

# Update the Bicep parameter file with the current user's object ID
$parameterFilePath = "main.parameters.json"
$parameterContent = Get-Content -Path $parameterFilePath -Raw | ConvertFrom-Json
$parameterContent.parameters.objectId.value = $currentObjectId
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
    -Mode Incremental `
    -Verbose

Write-Host "Deployment completed."
