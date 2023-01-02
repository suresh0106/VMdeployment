terraform {
  required_version = ">=0.12"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
    tls = {
      source = "hashicorp/tls"
      version = "~>4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "test-terraform1" {
  name     = "test-terraform"
  location = "central india"
}

resource "azurerm_virtual_network" "myvnet" {
  name                = "myterraform-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "central india"
  resource_group_name = azurerm_resource_group.test-terraform.name
}

resource "azurerm_subnet" "stagingsubnet" {
  name                 = "stagingSubnet"
  resource_group_name  = azurerm_resource_group.test-terraform.name
  virtual_network_name = azurerm_virtual_network.myvnet.name
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_subnet" "prodsubnet" {
  name                 = "prodSubnet"
  resource_group_name  = azurerm_resource_group.test-terraform.name
  virtual_network_name = azurerm_virtual_network.myvnet.name
  address_prefix       = "10.0.1.0/24"
}

resource "azurerm_public_ip" "stagingpublicip" {
  name                = "staging"
  location            = "central india"
  resource_group_name = azurerm_resource_group.test-terraform.name
  allocation_method   = "Static"
  sku                 = "standard"
}

resource "azurerm_network_interface" "stagingvm2nic" {
  name                = "stagingvm2-nic"
  location            = "central india"
  resource_group_name = azurerm_resource_group.test-terraform.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.stagingsubnet.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.stagingpublicip.id
  }
}
#NSG

resource "azurerm_network_security_group" "stagings-nsg01" {
  name                = "nsg-stagingsubnet"
  resource_group_name = azurerm_resource_group.test-terraform.name
  location            = "central india"
     
  tags = {
    "Environment" = "staging"
  }
}
#NSG Association

resource "azurerm_subnet_network_security_group_association" "stagings-nsg01" {
  subnet_id                 = azurerm_subnet.stagingsubnet.id
  network_security_group_id = azurerm_network_security_group.stagings-nsg01.id
  depends_on = [azurerm_network_security_group.stagings-nsg01]
  
 }
 resource "azurerm_network_security_rule" "RDP" {
  name                       = "RDP"
  priority                   = "1001"
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "3389"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
  resource_group_name = azurerm_resource_group.test-terraform.name
  network_security_group_name = azurerm_network_security_group.stagings-nsg01.name
 }
 resource "azurerm_network_security_rule" "SSH" {
  name                       = "SSH"
  priority                   = "1110"
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
  resource_group_name = azurerm_resource_group.test-terraform.name
  network_security_group_name = azurerm_network_security_group.stagings-nsg01.name
 }

resource "azurerm_windows_virtual_machine" "stagingVM" {
  name                  = "stagingVM"
  location              = "central india"
  resource_group_name   = azurerm_resource_group.test-terraform.name
  network_interface_ids = [azurerm_network_interface.stagingvm2nic.id]
  size                  = "Standard_D2as_v5"
  admin_username        = "adminuser"
  admin_password        = "Password123!"
   

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  os_disk {
    name                 = "myOsDisk"
    disk_size_gb         = "256"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
boot_diagnostics  {
    storage_account_uri = "https://stagingbootdiag001.blob.core.windows.net/"
  }
}
#stagingVM Datadisk01 

resource "azurerm_managed_disk" "datadisk_1" {
  name                 = "stagingvm_disk1"
  location             = azurerm_resource_group.test-terraform.location
  resource_group_name  = azurerm_resource_group.test-terraform.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "256"
}

resource "azurerm_virtual_machine_data_disk_attachment" "datadisk_1" {
  managed_disk_id    = azurerm_managed_disk.datadisk_1.id
  virtual_machine_id = azurerm_windows_virtual_machine.stagingVM.id
  lun                = "1"
  caching            = "ReadWrite"
}
# Create storage account for boot diagnostics

resource "azurerm_storage_account" "mystorageaccount" { 
  name                     = "stagingbootdiag001"
  location                 = azurerm_resource_group.test-terraform.location
  resource_group_name      = azurerm_resource_group.test-terraform.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}



