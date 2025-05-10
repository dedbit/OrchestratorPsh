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

resource "azurerm_resource_group" "state" {
  name     = "orchestratorPsh-state-dev-rg"
  location = "West Europe"
}

# Configure the Azure provider
provider "azurerm" {
  features {}
  subscription_id = var.config.subscription_id
  tenant_id       = var.config.tenant_id
}

resource "azurerm_storage_account" "state" {
  name                     = "orchestratorpshstatesa"
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"
}