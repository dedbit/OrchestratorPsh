# Azure infrastructure are deployed using Terraform

## Prerequisites

Terraform:

winget install --id Hashicorp.Terraform -e
terraform -version

az extension add --name automation

### 2. **Initialize Terraform**

```
cd Infrastructure

az login --tenant "6df08080-a31a-4efa-8c05-2373fc4515fc" 
az account set --subscription "d3e92861-7740-4f9f-8cd2-bdfe8dd4bde3"

az login --help

$context = Get-AzContext
$env:ARM_SUBSCRIPTION_ID = $context.Subscription.Id
$env:ARM_TENANT_ID = $context.Tenant.Id

$env:TF_LOG = "DEBUG"


# For state create account initial setup:
az group create --name orchestratorPsh-state-dev-rg --location "West Europe"
az storage account create --name orchestratorpshstatesa --resource-group orchestratorPsh-state-dev-rg --location "West Europe" --sku Standard_LRS
az storage container create --name tfstate --account-name orchestratorpshstatesa


```

Run the following command in the terminal to initialize Terraform and download the Azure provider:

```Powershell
new-alias tf terraform
terraform init

# Only run refresh if nothing else works. Use Init instead. 
# terraform refresh
```


terraform import azurerm_key_vault.example /subscriptions/d3e92861-7740-4f9f-8cd2-bdfe8dd4bde3/resourceGroups/orchestrator-terraform/providers/Microsoft.KeyVault/vaults/orchestrator-kv

terraform import azurerm_key_vault_secret https://orchestrator-kv.vault.azure.net/secrets/StorageAccountConnectionString/0a46a32856214b8eb023259298916e2c

### 3. **Preview the Changes**

Run the following command to see what Terraform will create:

```
# Help: terraform plan -help

terraform validate
terraform plan -out plan.tfplan
terraform apply plan.tfplan 


terraform plan
```

This will show a detailed list of resources that Terraform will provision.

### 4. **Apply the Configuration**

Run the following command to create the resources in Azure:

```
terraform apply -auto-approve
```
When prompted, type `yes` to confirm the changes.

```
terraform destroy -auto-approve


terraform destroy -auto-approve; terraform apply -auto-approve
```


### 

Install-Module -Name Terraform -Scope CurrentUser




# Issues to handle: 


│ The `azurerm_function_app` resource has been superseded by the
│ `azurerm_linux_function_app` and `azurerm_windows_function_app` resources. Whilst this
│ resource will continue to be available in the 2.x and 3.x releases it is feature-frozen
│ for compatibility purposes, will no longer receive any updates and will be removed in a
│ future major release of the Azure Provider.