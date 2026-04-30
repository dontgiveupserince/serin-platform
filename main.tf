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


# 1. Create a Public IP so you can connect from Schofields
resource "azurerm_public_ip" "vm_pip" {
  name                = "syd-platform-pip"
  resource_group_name = azurerm_resource_group.network_rg.name
  location            = azurerm_resource_group.network_rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 2. Create the Virtual Network Interface Card (NIC)
resource "azurerm_network_interface" "vm_nic" {
  name                = "syd-platform-nic"
  location            = azurerm_resource_group.network_rg.location
  resource_group_name = azurerm_resource_group.network_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_pip.id
  }
}

# --- COMPUTE SECTION ---

# 3. Create the Ubuntu Virtual Machine
resource "azurerm_linux_virtual_machine" "main_vm" {
  name                = "syd-platform-dev-001"
  resource_group_name = azurerm_resource_group.network_rg.name
  location            = azurerm_resource_group.network_rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "serinadmin"
  
  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]

  admin_ssh_key {
    username   = "serinadmin"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCZMa5coMinzVcDtvw4H1OHdbS548zc6Tal3f3bEzmLo0TZFflHhiGjqM9NAF81L9bGCPqyWsWBqBXBUbM2TQeLqF75pp2pXWF76/xUINXVi+DN8KGYI8Wn9OoK2K3FjrFZb000A2Ebw75LF4kF3Hx/PJijq+6g1yslw7LDhOKrE9tnF65Mm91EmxxIInsJnqgw5ssrty35L8htT+6i2QAgK7symiiNQC7ssOEQL2xFSv2/eVyJi3bP8q4FeG9H32/TsBSKa47/w+zmSDtASCGRNF9rCalCwd30VA+DNe+hzw1qUV/cAUpD6MziAWD4z1ScYIK37cNllmKb53X/ihKd44mKmWGhSR7yR+DLgmmdVxQHE3Q4e5hMB4m/zUFgrDmMQexlP8deS1INVjL+NOHYdWxGnfnP+1UoLWziWdDPSPFgnnyDSa6IpeVX4/rbENNbBD0k0UILvN6QiyujEi9jrS1hq9lUpHRejNGDAzA1fYRvP4Rg7vf9CZ/Ciz7gf3oX7q34JS9vCl0/rGiEkyajOBzUmO4LkHyw7j2hBwVol/OuBEyIi6+6LgK735gy86Uh+w4fjsJEsDe1Q6iynZ+b6ETsyKG0LLx228cRYyeciR1AHZBjFE+nIfSZrVUmOt/WhOAeOQZwnxBSitou829wrD9D+KI6mBbKcvVoCg5m+Q== serin@serinsfamily"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
    #cloud-config
    package_update: true
    packages:
      - docker.io
      - htop
    runcmd:
      - systemctl enable docker
      - systemctl start docker
      - usermod -aG docker serinadmin
  EOF
  )
}

# 1. Create the Security Group (The Firewall)
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "syd-platform-nsg"
  location            = azurerm_resource_group.network_rg.location
  resource_group_name = azurerm_resource_group.network_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*" # In production, we'd limit this to your Schofields IP
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*" # In production, we'd limit this to your Schofields IP
    destination_address_prefix = "*"
  }
}

# 2. Attach the Firewall to your Network Interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
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

  tags = {
    Environment = "Dev"
  }
}

# Output the Kubeconfig (You'll need this to talk to the cluster)
output "kube_config" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}
