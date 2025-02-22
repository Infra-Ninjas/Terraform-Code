# --------------------------------------------------------
# Terraform Block: Defines the required Terraform provider
# --------------------------------------------------------
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.90.0"
    }
  }
}

# --------------------------------------------------------
# Azure Provider Configuration
# --------------------------------------------------------
provider "azurerm" {
  features {}
}

# --------------------------------------------------------
# Resource Group: Creates a new Azure resource group
# --------------------------------------------------------
resource "azurerm_resource_group" "test" {
  name     = "test-resources-1"
  location = "East US"
}

# --------------------------------------------------------
# Virtual Network: Creates a VNet for the VM
# --------------------------------------------------------
resource "azurerm_virtual_network" "test" {
  name                = "test-network"
  address_space       = ["10.0.0.0/16"] # CIDR range for the VNet
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
}

# --------------------------------------------------------
# Subnet: Creates a subnet within the VNet
# --------------------------------------------------------
resource "azurerm_subnet" "test" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.test.name
  virtual_network_name = azurerm_virtual_network.test.name
  address_prefixes     = ["10.0.2.0/24"] # CIDR range for the subnet
}

# --------------------------------------------------------
# Public IP: Creates a public IP for the VM
# --------------------------------------------------------
resource "azurerm_public_ip" "test" {
  name                = "test_pip"
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location
  allocation_method   = "Static" # IP will not change upon restart
}

# --------------------------------------------------------
# Network Security Group: Creates a new NSG to allow SSH and HTTP access
# --------------------------------------------------------
resource "azurerm_network_security_group" "test" {
  name                = "test-nsg"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Port-4000"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Port-5000"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTP (port 8000) for React app
  security_rule {
    name                       = "Allow-Port-8000"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# --------------------------------------------------------
# Network Interface: Associates the VM with the subnet and public IP
# --------------------------------------------------------
resource "azurerm_network_interface" "test" {
  name                = "test-nic"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.test.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.test.id
  }
}

# --------------------------------------------------------
# Associate the NSG with the Network Interface
# --------------------------------------------------------
resource "azurerm_network_interface_security_group_association" "test" {
  network_interface_id      = azurerm_network_interface.test.id
  network_security_group_id = azurerm_network_security_group.test.id
}

# --------------------------------------------------------
# Virtual Machine: Deploys an Ubuntu VM in Azure
# --------------------------------------------------------
resource "azurerm_linux_virtual_machine" "test" {
  name                            = "test-machine"
  resource_group_name             = azurerm_resource_group.test.name
  location                        = azurerm_resource_group.test.location
  size                            = "Standard_D2s_v3"
  admin_username                  = "adminuser"
  disable_password_authentication = true # Disables password login for security

  network_interface_ids = [
    azurerm_network_interface.test.id,
  ]

  # SSH Key Configuration
  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub") # Uses existing SSH key
  }

  # OS Disk Configuration
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # OS Image: Ubuntu 22.04 LTS
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # Enable system-assigned managed identity
  identity {
    type = "SystemAssigned"
  }
}

# # Grant ACR Pull Role to VM
# resource "azurerm_role_definition" "acr_pull_custom" {
#   name        = "AcrPullCustom"
#   scope       = azurerm_container_registry.test.id
#   description = "Custom role to pull images from ACR"

#   permissions {
#     actions = [
#       "Microsoft.ContainerRegistry/registries/pull/read"
#     ]
#     not_actions = []
#   }

#   assignable_scopes = [
#     azurerm_container_registry.test.id
#   ]
# }

# resource "azurerm_role_assignment" "acr_pull" {
#   scope              = azurerm_container_registry.test.id
#   role_definition_id = azurerm_role_definition.acr_pull_custom.role_definition_resource_id
#   principal_id       = azurerm_linux_virtual_machine.test.identity[0].principal_id

#   lifecycle {
#     prevent_destroy = true
#   }

#   depends_on = [azurerm_role_definition.acr_pull_custom]
# }

# Grant ACR Pull Role to VM
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.test.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_virtual_machine.test.identity[0].principal_id

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [azurerm_container_registry.test] # Ensures ACR is created first
}

# --------------------------------------------------------
# Azure Container Registry (ACR): Creates a private container registry
# --------------------------------------------------------
resource "azurerm_container_registry" "test" {
  name                = "rupeshcapstoneacr" # Must be globally unique
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location
  sku                 = "Basic" # Options: Basic, Standard, Premium
  admin_enabled       = true    # Enables admin login for easier access
}

# # --------------------------------------------------------
# # Storage Account: Creates a new Azure Storage Account
# # --------------------------------------------------------
# resource "azurerm_storage_account" "test" {
#   name                     = "rupeshcapstonesa" # Must be globally unique
#   resource_group_name      = azurerm_resource_group.test.name
#   location                 = azurerm_resource_group.test.location
#   account_tier             = "Standard"
#   account_replication_type = "LRS" # Locally redundant storage (LRS)

#   tags = {
#     environment = "test"
#   }
# }

# # --------------------------------------------------------
# # Blob Container: Creates a container inside the Storage Account for the tfstate file
# # --------------------------------------------------------
# resource "azurerm_storage_container" "tfstate" {
#   name                  = "tfstate-container" # Container for tfstate files
#   storage_account_name  = azurerm_storage_account.test.name
#   container_access_type = "private" # Keeps it private for security reasons
# }
