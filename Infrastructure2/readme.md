# Azure Infrastructure deployed using Bicep

This folder contains Bicep templates and deployment scripts for provisioning Azure resources. 

## Prerequisites

### 1. **Install Required Tools**

#### Azure PowerShell
```powershell
# Check if PowerShell Az module is installed
Get-Module -Name Az -ListAvailable

# If not installed, install the Az module
Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force

# Import the module
Import-Module Az
```

### 2. **Sign in to Azure**

```powershell
# Navigate to the Infrastructure2 directory
cd Infrastructure2

# Sign in to Azure with a specific tenant and subscription
Connect-AzAccount -TenantId "6df08080-a31a-4efa-8c05-2373fc4515fc" -SubscriptionId "d3e92861-7740-4f9f-8cd2-bdfe8dd4bde3"

# Verify and store the context for use in scripts
$context = Get-AzContext
```

### 3. **Deploy the Bicep Template**

#### Option 1: Using the Deployment Script

Run the PowerShell deployment script which handles:
- Getting the current user's Object ID
- Updating the parameter file
- Creating the resource group if needed
- Deploying the Bicep template

```powershell
./deploy-bicep.ps1
```

#### Option 2: Manual Deployment

If you prefer manual deployment, you can use PowerShell commands directly:

```powershell
# Make sure you are in the Infrastructure2 directory
cd Infrastructure2

# Create resource group if it doesn't exist
$resourceGroupName = "orchestratorPsh2-dev-rg"
$location = "West Europe"

$rgExists = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if (-not $rgExists) {
    New-AzResourceGroup -Name $resourceGroupName -Location $location
    Write-Host "Resource group '$resourceGroupName' created."
}

# Get the current user's Object ID for Key Vault access
$currentUser = Get-AzADUser -SignedIn
$currentObjectId = $currentUser.Id

# Update the parameter file with the current user's object ID
$parameterFilePath = "main.parameters.json"
$parameterContent = Get-Content -Path $parameterFilePath -Raw | ConvertFrom-Json
$parameterContent.parameters.objectId.value = $currentObjectId
$parameterContent | ConvertTo-Json -Depth 10 | Set-Content -Path $parameterFilePath

# Deploy the Bicep template with parameters
New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile "main.bicep" `
    -TemplateParameterFile $parameterFilePath `
    -Mode Incremental
```

### 4. **Verify Deployment**

After deployment, verify that resources were created correctly:

```powershell
# List resources in the resource group
Get-AzResource -ResourceGroupName orchestratorPsh-dev-rg

# Get details about a specific resource (e.g., Key Vault)
Get-AzKeyVault -ResourceGroupName orchestratorPsh-dev-rg -VaultName "orchestrator2psh-kv"
```

### 5. **Clean Up Resources**

To delete all resources deployed:

```powershell
# Remove the entire resource group
Remove-AzResourceGroup -Name orchestratorPsh-dev-rg -Force
```

## Importing Existing Resources

If you need to import an existing Azure resource's configuration into your Bicep template, you can use PowerShell to export the resource to an ARM template (which you can then convert to Bicep):

```powershell
# Export a resource group to ARM template
Export-AzResourceGroup -ResourceGroupName orchestratorPsh-dev-rg -Path ./exported.json -IncludeParameterDefaultValue

# Convert to Bicep (requires Bicep CLI to be installed)
bicep decompile ./exported.json
```

## Notes

- The Bicep template creates a Key Vault with network rules and access policies
- Access policies are set for the current user based on the Object ID provided during deployment
- The template includes a secret named "PAT" in the Key Vault
- The deployment script handles obtaining the current user's Object ID and updating the parameters file

## Troubleshooting

If you encounter issues during deployment:

1. Ensure you're signed in to the correct tenant and subscription
2. Check that you have the necessary permissions to create resources
3. Review any error messages in the output
4. Enable verbose logging for more detailed information:

```powershell
$VerbosePreference = "Continue"
./deploy-bicep.ps1
```
