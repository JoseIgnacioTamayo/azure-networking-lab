/* Spoke Network connected to Hub via Peering

The Subnets routes 10.0.0.0/8 to AzFw in Hub, 0/0 and ::/0 are left to Internet.

VM with UserManagedIdentity (admin password as file), accesible only for Bastion
az-cli is installed via startup script
VM has IPv4 and IPv6 addresses

Peered with Spoke for IPv6 (AzFw cannot be IPv6 transit)

*/

resource "azurerm_virtual_network" "spoke2" {
  name                = "vnet-spoke-2"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = local.location
  address_space       = ["10.0.2.0/24", "fd00:2::/48"]
}

resource "azurerm_subnet" "spoke2_subnet1" {
  name                 = "snet-1"
  virtual_network_name = azurerm_virtual_network.spoke2.name
  resource_group_name  = data.azurerm_resource_group.rg.name
  address_prefixes     = ["10.0.2.0/26", "fd00:2::/64"]
  service_endpoints    = ["Microsoft.Storage"]
}

resource "azurerm_subnet" "spoke2_subnet2" {
  name                 = "snet-2"
  virtual_network_name = azurerm_virtual_network.spoke2.name
  resource_group_name  = data.azurerm_resource_group.rg.name
  address_prefixes     = ["10.0.2.128/26", "fd00:2:0:F000::/64"]
  service_endpoints    = ["Microsoft.Storage"]
}

resource "azurerm_subnet_route_table_association" "spoke2_subnet1" {
  subnet_id      = azurerm_subnet.spoke2_subnet1.id
  route_table_id = azurerm_route_table.default_spoke2.id
}

resource "azurerm_subnet_network_security_group_association" "spoke2_subnet2" {
  subnet_id                 = azurerm_subnet.spoke2_subnet2.id
  network_security_group_id = azurerm_network_security_group.default_spoke2.id
}

resource "azurerm_virtual_network_peering" "spoke2_to_hub" {
  name                         = "peer-spoke2-to-hub"
  resource_group_name          = data.azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.spoke2.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  # cannot have UseRemoteGateway flag set to true because remote virtual network has no GWs
  use_remote_gateways = false
}

resource "azurerm_virtual_network_peering" "hub_to_spoke2" {
  name                         = "peer-hub-to-spoke2"
  resource_group_name          = data.azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke2_to_spoke1" {
  name                         = "peer-spoke2-to-spoke1"
  resource_group_name          = data.azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.spoke2.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
}

resource "azurerm_route_table" "default_spoke2" {
  name                = "rt-default-spoke-2"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name

  route {
    name                   = "default4"
    address_prefix         = "10.0.0.0/8"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
  }
  # Because of Peering, exact-subnet rules are needed so traffic goes via AzFw
  route {
    name                   = "spoke1_subnet1"
    address_prefix         = "10.0.1.0/26"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_network_security_group" "default_spoke2" {
  name                = "nsg-default-spoke-2"
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

resource "azurerm_network_interface" "spoke2_vm" {
  name                = "nic-spoke2-1"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = local.location

  ip_configuration {
    name                          = "internal4"
    subnet_id                     = azurerm_subnet.spoke2_subnet2.id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
    primary                       = true
  }
  ip_configuration {
    name                          = "internal6"
    subnet_id                     = azurerm_subnet.spoke2_subnet2.id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv6"
  }

}

resource "azurerm_linux_virtual_machine" "spoke2_vm" {
  name                = "vm-userid-spoke2"
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
    azurerm_network_interface.spoke2_vm.id,
  ]

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.robot_me.id]
  }

  custom_data = base64encode(file("./startup.sh"))

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
