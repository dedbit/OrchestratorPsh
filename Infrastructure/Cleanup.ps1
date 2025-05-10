# Cleanup script deletes all resources and resource group using Azure CLI.

# Function to clean up resources and resource group using Azure CLI
function Cleanup-Resources {
    param (
        [string]$ResourceGroup
    )

    # Get all Key Vaults in the resource group
    $keyVaults = az keyvault list --resource-group $ResourceGroup --query "[].name" -o tsv

    foreach ($vault in $keyVaults) {
        # Purge each Key Vault (removes from soft-delete)
        az keyvault delete --name $vault --resource-group $ResourceGroup
        az keyvault purge --name $vault
    }

    # Remove the entire resource group
    az group delete --name $ResourceGroup --yes --no-wait
}



$resourceGroup = "orchestratorPsh-dev-rg"
Cleanup-Resources $resourceGroup