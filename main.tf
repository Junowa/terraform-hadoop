# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "myterraformgroup" {
    name     = "hadoop"
    location = "westeurope"
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "hadoop"
    address_space       = ["10.0.0.0/16"]
    location            = "westeurope"
    resource_group_name = azurerm_resource_group.myterraformgroup.name
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "hadoop"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "node1-public-ip"
    location                     = "westeurope"
    resource_group_name          = azurerm_resource_group.myterraformgroup.name
    allocation_method            = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "hadoop"
    location            = "westeurope"
    resource_group_name = azurerm_resource_group.myterraformgroup.name
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefixes   = var.trusted_ip_list
        destination_address_prefix = "*"
    }
        security_rule {
        name                       = "HTTP"
        priority                   = 1100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "8080"
        source_address_prefixes    = var.trusted_ip_list
        destination_address_prefix = "*"
    }
}

# Create network interface
resource "azurerm_network_interface" "node1" {
    name                      = "node1"
    location                  = "westeurope"
    resource_group_name       = azurerm_resource_group.myterraformgroup.name
    network_security_group_id = azurerm_network_security_group.myterraformnsg.id

    ip_configuration {
        name                          = "node1"
        subnet_id                     = azurerm_subnet.myterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.myterraformgroup.name
    }
    
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.myterraformgroup.name
    location                    = "westeurope"
    account_tier                = "Standard"
    account_replication_type    = "LRS"
}

# Logs available: /var/lib/waagent/Microsoft.Azure.Extensions.CustomScript-2.0.7/status
resource "azurerm_virtual_machine_extension" "node1" {

    resource_group_name     = azurerm_resource_group.myterraformgroup.name
    location                = azurerm_resource_group.myterraformgroup.location
    name                    = "node1"

    virtual_machine_name = azurerm_virtual_machine.node1.name
    publisher            = "Microsoft.Azure.Extensions"
    type                 = "CustomScript"
    type_handler_version = "2.0"

    protected_settings = <<PROT
    {
        "script": "${base64encode(file("install_ambari_server.sh"))}"
    }
    PROT
}

# Create virtual machine
resource "azurerm_virtual_machine" "node1" {
    name                  = "node1"
    location              = "westeurope"
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [azurerm_network_interface.node1.id]
    vm_size               = "Standard_B2S"

    storage_os_disk {
        name              = "node1disk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "openLogic"
        offer = "CentOS"
        sku = "7.7"
        version = "latest"
    }

    os_profile {
        computer_name  = "node1"
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = var.ssh_key
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }
}

# Node2

resource "azurerm_network_interface" "node2" {
    name                      = "node2"
    location                  = "westeurope"
    resource_group_name       = azurerm_resource_group.myterraformgroup.name
    network_security_group_id = azurerm_network_security_group.myterraformnsg.id

    ip_configuration {
        name                          = "node2"
        subnet_id                     = azurerm_subnet.myterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
    }
}

resource "azurerm_virtual_machine_extension" "node2" {

    resource_group_name     = azurerm_resource_group.myterraformgroup.name
    location                = azurerm_resource_group.myterraformgroup.location
    name                    = "node2"

    virtual_machine_name = azurerm_virtual_machine.node2.name
    publisher            = "Microsoft.Azure.Extensions"
    type                 = "CustomScript"
    type_handler_version = "2.0"

    protected_settings = <<PROT
    {
        "script": "${base64encode(file("install_ambari_agent.sh"))}"
    }
    PROT
}

resource "azurerm_virtual_machine" "node2" {
    name                  = "node2"
    location              = "westeurope"
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [azurerm_network_interface.node2.id]
    vm_size               = "Standard_B2S"

    storage_os_disk {
        name              = "node2disk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "openLogic"
        offer = "CentOS"
        sku = "7.7"
        version = "latest"
    }

    os_profile {
        computer_name  = "node2"
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = var.ssh_key
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }
}

# node3

resource "azurerm_network_interface" "node3" {
    name                      = "node3"
    location                  = "westeurope"
    resource_group_name       = azurerm_resource_group.myterraformgroup.name
    network_security_group_id = azurerm_network_security_group.myterraformnsg.id

    ip_configuration {
        name                          = "node3"
        subnet_id                     = azurerm_subnet.myterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
    }
}

# Logs available: /var/lib/waagent/Microsoft.Azure.Extensions.CustomScript-2.0.7/status
resource "azurerm_virtual_machine_extension" "node3" {

    resource_group_name     = azurerm_resource_group.myterraformgroup.name
    location                = azurerm_resource_group.myterraformgroup.location
    name                    = "node3"

    virtual_machine_name = azurerm_virtual_machine.node3.name
    publisher            = "Microsoft.Azure.Extensions"
    type                 = "CustomScript"
    type_handler_version = "2.0"

    protected_settings = <<PROT
    {
        "script": "${base64encode(file("install_ambari_agent.sh"))}"
    }
    PROT
}

# Create virtual machine
resource "azurerm_virtual_machine" "node3" {
    name                  = "node3"
    location              = "westeurope"
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [azurerm_network_interface.node3.id]
    vm_size               = "Standard_B2S"

    storage_os_disk {
        name              = "node3disk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "openLogic"
        offer = "CentOS"
        sku = "7.7"
        version = "latest"
    }

    os_profile {
        computer_name  = "node3"
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = var.ssh_key
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }
}
