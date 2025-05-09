terraform {
  backend "azurerm" {
    resource_group_name  = "orchestratorPsh-state-dev-rg"  # Match the resource group from state.tf
    storage_account_name = "orchestratorpshstatedevsa"    # Match the storage account name from state.tf
    container_name       = "tfstate"                  # Match the container name from state.tf
    key                  = "terraform.tfstate"        # Specify the state file name
  }
}

variable "input_parameters" {
  description = "Common input parameters for the Terraform configuration"
  type = object({
    github_repo_url = string
    another_variable = string
    yet_another_variable = string
  })
  default = {
    github_repo_url     = ""
    another_variable    = "default_value"
    yet_another_variable = "default_value"
  }
}


# Define variables for resource names, tenant ID, and subscription ID
variable "config" {
  default = {
    resource_names = {
      resource_group_name         = "orchestratorPsh-dev-rg"
      key_vault_name              = "orchestrator2psh-kv" 
    }
    tenant_id       = "6df08080-a31a-4efa-8c05-2373fc4515fc"
    subscription_id = "d3e92861-7740-4f9f-8cd2-bdfe8dd4bde3"
  }
}

# Configure the Azure provider
provider "azurerm" {
  features {}
  subscription_id = var.config.subscription_id
  tenant_id       = var.config.tenant_id
}

# Retrieve the current user's object ID
data "azuread_client_config" "current" {}

# Define a resource group
resource "azurerm_resource_group" "example" {
  name     = var.config.resource_names.resource_group_name
  location = "West Europe"

  tags = {
    GitHubRepo = var.input_parameters.github_repo_url
    AnotherTag = var.input_parameters.another_variable
  }
}

# Define a KeyVault
resource "azurerm_key_vault" "example" {
  name                        = var.config.resource_names.key_vault_name
  location                    = azurerm_resource_group.example.location
  resource_group_name         = azurerm_resource_group.example.name
  tenant_id                   = var.config.tenant_id
  sku_name                    = "standard"

  access_policy {
    tenant_id = var.config.tenant_id
    object_id = data.azuread_client_config.current.object_id
    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete"
    ]
  }

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"

    ip_rules = [
      "185.162.105.4",
      "87.63.79.239"
    ]
  }
}

resource "azurerm_key_vault_secret" "pat" {
  name         = "PAT"
  value        = ""
  key_vault_id = azurerm_key_vault.example.id
}

resource "azurerm_key_vault_access_policy" "example" {
  key_vault_id = azurerm_key_vault.example.id
  tenant_id    = var.config.tenant_id
  object_id    = data.azuread_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Recover",
    "Backup",
    "Restore"
  ]
}

output "deployment_outputs" {
  value = {
    function_app_hostname = azurerm_linux_function_app.example.default_hostname
    function_app_name     = azurerm_linux_function_app.example.name
    resource_group_name   = var.config.resource_names.resource_group_name
    subscription_id       = var.config.subscription_id
    key_vault_name        = var.config.resource_names.key_vault_name
  }
}
