terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "serin-tfstate-rg"
    storage_account_name = "serinst5640"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "network_rg" {
  name     = "serin-network-rg"
  location = "Australia East"
}

resource "azurerm_virtual_network" "main_vnet" {
  name                = "serin-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "Australia East"
  resource_group_name = azurerm_resource_group.network_rg.name
}

resource "azurerm_subnet" "public" {
  name                 = "public-subnet"
  resource_group_name  = azurerm_resource_group.network_rg.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}


# Create the Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "serinregistry${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.network_rg.name
  location            = azurerm_resource_group.network_rg.location
  sku                 = "Basic"
  admin_enabled       = true # Allows us to use a username/password for login
}

# Generates a random suffix because ACR names must be unique across all of Azure
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

# Create the AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "serin-aks-cluster"
  location            = azurerm_resource_group.network_rg.location
  resource_group_name = azurerm_resource_group.network_rg.name
  dns_prefix          = "serinaks"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2s_v3" # Small and cost-effective for learning
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
  }

  tags = {
    Environment = "Dev"
  }
}

# Output the Kubeconfig (You'll need this to talk to the cluster)
output "kube_config" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
  lifecycle {
    ignore_changes = all
  }
}
