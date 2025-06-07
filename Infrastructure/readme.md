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

# Load tenant and subscription IDs from environment configuration
$envConfig = Get-Content -Path "..\environments\dev.json" -Raw | ConvertFrom-Json
$tenantId = $envConfig.tenantId
$subscriptionId = $envConfig.subscriptionId

# Sign in to Azure with tenant and subscription IDs from config
Connect-AzAccount -TenantId $tenantId -SubscriptionId $subscriptionId

# Verify and store the context for use in scripts
$context = Get-AzContext
```

### 3. **Deploy the Bicep Template**

#### Option 1: Using the Deployment Script

Run the PowerShell deployment script which handles:
- Getting the current user's Object ID
- Getting GitHub repo URL from git configuration
- Updating the parameter file
- Creating the resource group if needed
- Deploying the Bicep template

```powershell
# Basic usage - gets GitHub repo URL from git configuration
./deploy-bicep.ps1

# Override the GitHub repo URL parameter when calling the script
./deploy-bicep.ps1 -GithubRepoUrl "https://github.com/myorg/myrepo"
```


### 4. **Verify Deployment**

After deployment, verify that resources were created correctly:

```powershell
# List resources in the resource group
Get-AzResource -ResourceGroupName orchestratorPsh2-dev-rg

# Get details about a specific resource (e.g., Key Vault)
Get-AzKeyVault -ResourceGroupName orchestratorPsh2-dev-rg -VaultName "orchestrator2psh2-kv"
```

### 5. **Clean Up Resources**

To delete all resources deployed, including permanent removal of the Key Vault from the soft-delete (recycle bin):

```powershell
# Run the termination script which:
# 1. Deletes the resource group and all resources
# 2. Purges the Key Vault from soft-delete (recycle bin)
./Terminate.ps1

# Specify custom resource group or key vault name
./Terminate.ps1 -ResourceGroupName "custom-rg-name" -KeyVaultName "custom-kv-name"
```

## Importing Existing Resources

If you need to import an existing Azure resource's configuration into your Bicep template, you can use PowerShell to export the resource to an ARM template (which you can then convert to Bicep):

```powershell
# Export a resource group to ARM template
Export-AzResourceGroup -ResourceGroupName orchestratorPsh-dev-rg -Path ./exported.json -IncludeParameterDefaultValue

# Convert to Bicep (requires Bicep CLI to be installed)
bicep decompile ./exported.json
```

## Dynamic Parameter Handling

The deployment script supports several methods for parameter values:

1. **Environment Configuration**: Key parameters are loaded from `environments/dev.json`:
   - Tenant ID
   - Subscription ID
   - Key Vault Name
   - Resource Group Name
   - Storage Account Name
   - Cosmos DB Account Name

   ```powershell
   # Synchronize parameters between environments/dev.json and main.parameters.json
   ./sync-parameters.ps1
   ```

2. **Script Parameters**: Pass values directly when calling the script:
   ```powershell
   ./deploy-bicep.ps1 -GithubRepoUrl "https://github.com/myorg/myrepo"
   ```

3. **Git Repository URL**: If not explicitly provided, the script will attempt to get the GitHub repository URL from git configuration:
   ```powershell
   # This is executed in the script when no GithubRepoUrl is provided
   $repoUrl = git config --get remote.origin.url
   ```

4. **Parameters File**: The script updates the `main.parameters.json` file with values from environment config and script parameters before deployment.

5. **Override at Deployment**: Parameters are passed both through the parameters file and directly to the deployment command to ensure they take precedence.

## Notes

### Configuration and Parameters
- **Environment Configuration**: Tenant ID, Subscription ID, Key Vault Name, Resource Group Name, Storage Account Name, and Cosmos DB Account Name are loaded from `environments/dev.json` file
- **Parameters File**: The deployment script updates `main.parameters.json` automatically with values from environment config
- **GitHub Repo URL**: Automatically detected from git configuration if not provided explicitly
- **Object ID**: Obtained from the currently signed-in user for Key Vault access policies

### Resource Features
- **Key Vault**: Created with network rules (IP-based access restrictions) and access policies 
- **PAT Secret**: The template includes a secret named "PAT" in the Key Vault
- **Cosmos DB**: Serverless Cosmos DB account (cheapest tier) for data storage with "OrchestratorDb" database and "Items" container
- **Cosmos DB Connection String**: Automatically stored as "CosmosDbConnectionString" secret in Key Vault
- **Storage Account**: Standard LRS storage account for blob storage needs
- **Access Policies**: Set automatically for the current user based on the Object ID

### Synchronization
- The `sync-parameters.ps1` script ensures consistency between environment config and parameter files

## Troubleshooting

If you encounter issues during deployment:

1. Ensure you're signed in to the correct tenant and subscription (configured in `environments/dev.json`)
2. Check that you have the necessary permissions to create resources
3. Review any error messages in the output
4. Verify that the `environments/dev.json` file contains valid tenantId and subscriptionId values
5. Enable verbose logging for more detailed information:

```powershell
$VerbosePreference = "Continue"
./deploy-bicep.ps1
```
