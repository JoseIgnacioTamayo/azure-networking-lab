/* Spoke Network connected to Hub via Peering

The Subnet routes IPv4 to AzFw in Hub.

VM accesible only for Bastion
TCP 8080-80802 accesible only for AppGw
VM has IPv4 addresses

*/


resource "azurerm_virtual_network" "spoke3" {
  name                = "vnet-spoke-3"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = local.location
  address_space       = ["10.0.3.0/24"]
}

resource "azurerm_subnet" "spoke3_subnet1" {
  name                 = "snet-1"
  virtual_network_name = azurerm_virtual_network.spoke3.name
  resource_group_name  = data.azurerm_resource_group.rg.name
  address_prefixes     = ["10.0.3.0/26"]
}

resource "azurerm_subnet" "AppGwSubnet" {
  name                 = "AppGwSubnet"
  virtual_network_name = azurerm_virtual_network.spoke3.name
  resource_group_name  = data.azurerm_resource_group.rg.name
  address_prefixes     = ["10.0.3.128/26"]
}

resource "azurerm_subnet_route_table_association" "spoke3_subnet1" {
  subnet_id      = azurerm_subnet.spoke3_subnet1.id
  route_table_id = azurerm_route_table.default_spoke3.id
}

resource "azurerm_subnet_network_security_group_association" "spoke3_subnet1" {
  subnet_id                 = azurerm_subnet.spoke3_subnet1.id
  network_security_group_id = azurerm_network_security_group.default_spoke3.id
}

resource "azurerm_route_table" "default_spoke3" {
  name                = "rt-default-spoke-3"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name
  disable_bgp_route_propagation = true

  route {
    name                   = "defaultV4"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_network_security_group" "default_spoke3" {
  name                = "nsg-default-spoke-3"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "bastion-allow-in"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefixes    = azurerm_subnet.AzureBastionSubnet.address_prefixes
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                         = "appgw-allow-in"
    priority                     = 130
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "8080-8082"
    source_address_prefixes        =  azurerm_subnet.AppGwSubnet.address_prefixes
    destination_address_prefix   = "VirtualNetwork"
  }
  security_rule {
    name                       = "all-deny-in"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }
}


resource "azurerm_virtual_network_peering" "hub_to_spoke3" {
  name                         = "peer-hub-to-spoke3"
  resource_group_name          = data.azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke3.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}


resource "azurerm_network_interface" "spoke3" {
  name                = "nic-spoke3-1"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = local.location

  ip_configuration {
    name                          = "internal4"
    subnet_id                     = azurerm_subnet.spoke3_subnet1.id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
    primary                       = true
  }

}

resource "azurerm_linux_virtual_machine" "spoke3" {
  name                = "vm-spoke3-1"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = local.location
  size                = "Standard_B4ms"
  admin_username      = "adminuser"

  admin_ssh_key {
    username   = "adminuser"
    public_key = file(var.vm_ssh_key_file)
  }

  disable_password_authentication = true
  network_interface_ids = [
    azurerm_network_interface.spoke3.id,
  ]

  custom_data = filebase64("./startup_web.sh")

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadOnly"

    # Ephemeral Disk
    diff_disk_settings {
      option    = "Local"
      placement = "ResourceDisk"
    }
  }
}
