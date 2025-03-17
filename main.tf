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
resource "azurerm_resource_group" "healthsync" {
  name     = "healthsync-rg"
  location = "East US"
}

# --------------------------------------------------------
# Virtual Network: Creates a VNet for the VM
# --------------------------------------------------------
resource "azurerm_virtual_network" "healthsync" {
  name                = "healthsync-network"
  address_space       = ["10.0.0.0/16"] # CIDR range for the VNet
  location            = azurerm_resource_group.healthsync.location
  resource_group_name = azurerm_resource_group.healthsync.name
}

# --------------------------------------------------------
# Subnet: Creates a subnet within the VNet
# --------------------------------------------------------
resource "azurerm_subnet" "healthsync" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.healthsync.name
  virtual_network_name = azurerm_virtual_network.healthsync.name
  address_prefixes     = ["10.0.1.0/24"] # CIDR range for the subnet
}

# --------------------------------------------------------
# Public IP: Creates a public IP for the VM
# --------------------------------------------------------
resource "azurerm_public_ip" "healthsync" {
  name                = "healthsync_pip"
  resource_group_name = azurerm_resource_group.healthsync.name
  location            = azurerm_resource_group.healthsync.location
  allocation_method   = "Static" # IP will not change upon restart
  domain_name_label   = "healthsync"
}

# --------------------------------------------------------
# Network Security Group: Creates a new NSG to allow SSH and HTTP access
# --------------------------------------------------------
resource "azurerm_network_security_group" "healthsync" {
  name                = "healthsync-nsg"
  location            = azurerm_resource_group.healthsync.location
  resource_group_name = azurerm_resource_group.healthsync.name

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
    name                       = "Microservices-Ports"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4000-4010"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "DB-Port-5000"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTP (port 80) for React app
  security_rule {
    name                       = "Frontend-Port-80"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# --------------------------------------------------------
# Network Interface: Associates the VM with the subnet and public IP
# --------------------------------------------------------
resource "azurerm_network_interface" "healthsync" {
  name                = "healthsync-nic"
  location            = azurerm_resource_group.healthsync.location
  resource_group_name = azurerm_resource_group.healthsync.name
  ip_configuration {
    name                          = "healthsync"
    subnet_id                     = azurerm_subnet.healthsync.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.healthsync.id
  }
}

# --------------------------------------------------------
# Associate the NSG with the Network Interface
# --------------------------------------------------------
resource "azurerm_network_interface_security_group_association" "healthsync" {
  network_interface_id      = azurerm_network_interface.healthsync.id
  network_security_group_id = azurerm_network_security_group.healthsync.id
}

# --------------------------------------------------------
# Virtual Machine: Deploys an Ubuntu VM in Azure
# --------------------------------------------------------
resource "azurerm_linux_virtual_machine" "healthsync" {
  name                            = "healthsync-machine"
  resource_group_name             = azurerm_resource_group.healthsync.name
  location                        = azurerm_resource_group.healthsync.location
  size                            = "Standard_B2s"
  admin_username                  = "adminuser"
  disable_password_authentication = true # Disables password login for security

  network_interface_ids = [
    azurerm_network_interface.healthsync.id,
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

# Grant ACR Pull Role to VM
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.healthsync.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_virtual_machine.healthsync.identity[0].principal_id
  depends_on           = [azurerm_container_registry.healthsync] # Ensures ACR is created first
}

# --------------------------------------------------------
# Azure Container Registry (ACR): Creates a private container registry
# --------------------------------------------------------
resource "azurerm_container_registry" "healthsync" {
  name                = "healthsyncacr" # Must be globally unique
  resource_group_name = azurerm_resource_group.healthsync.name
  location            = azurerm_resource_group.healthsync.location
  sku                 = "Basic" # Options: Basic, Standard, Premium
  admin_enabled       = true    # Enables admin login for easier access
}

# --------------------------------------------------------
# Output: Displays the public IP of the VM
# --------------------------------------------------------
output "public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.healthsync.ip_address
}