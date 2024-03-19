/* Spoke Network connected to Hub via Peering

The Subnet routes IPv4 to AzFw in Hub.

VMSS with SystemManagedIdentity (admin password as file), accesible only for Bastion
VMSS Identity is given READER Roll in the ResourceGroup
az-cli is installed via startup script
VMSS have IPv4 and IPv6 addresses

Peered with Spoke for IPv6 (AzFw cannot be IPv6 transit)

*/

resource "azurerm_virtual_network" "spoke1" {
  name                = "vnet-spoke-1"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = local.location
  address_space       = ["10.0.1.0/24", "fd00:1::/48"]
}

resource "azurerm_subnet" "spoke1_subnet1" {
  name                 = "snet-1"
  virtual_network_name = azurerm_virtual_network.spoke1.name
  resource_group_name  = data.azurerm_resource_group.rg.name
  address_prefixes     = ["10.0.1.0/26", "fd00:1::/64"]
}

resource "azurerm_subnet_route_table_association" "spoke1_subnet1" {
  subnet_id      = azurerm_subnet.spoke1_subnet1.id
  route_table_id = azurerm_route_table.default_spoke1.id
}

resource "azurerm_subnet_network_security_group_association" "spoke1_subnet1" {
  subnet_id                 = azurerm_subnet.spoke1_subnet1.id
  network_security_group_id = azurerm_network_security_group.default_spoke1.id
}

resource "azurerm_route_table" "default_spoke1" {
  name                = "rt-default-spoke-1"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name

  route {
    name                   = "defaultV4"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
  }
  # Because of Peering, exact-subnet rules are needed so traffic goes via AzFw
  route {
    name                   = "spoke2_subnet1"
    address_prefix         = "10.0.2.0/26"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
  }
  route {
    name                   = "spoke2_subnet2"
    address_prefix         = "10.0.2.128/26"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_network_security_group" "default_spoke1" {
  name                = "nsg-default-spoke-1"
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
    name                    = "httpV4-allow-in"
    priority                = 110
    direction               = "Inbound"
    access                  = "Allow"
    protocol                = "Tcp"
    source_port_range       = "*"
    destination_port_ranges = ["8080", "80"]
    # All IP addresses or prefixes in the resource should belong to the same address family
    source_address_prefix      = "VirtualNetwork" # A Rule can only have IPs of the same Protocol
    destination_address_prefix = "10.0.1.0/26"
    # Cannot use 'azurerm_subnet.spoke1_subnet1.address_prefixes' because it has IPv4 and IPv6
  }
  security_rule {
    name                       = "httpV6-allow-in"
    priority                   = 120 # Rules MUST have different priority, and different names
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8081", "80"]
    source_address_prefix      = "fd00::/16"
    destination_address_prefix = "fd00:1::/64"
  }
  security_rule {
    name                       = "healthprobe-allow-in"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8080"]
    source_address_prefix      = "AzureLoadBalancer"
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

resource "azurerm_virtual_network_peering" "spoke1_to_hub" {
  name                         = "peer-spoke1-to-hub"
  resource_group_name          = data.azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.spoke1.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  # cannot have UseRemoteGateway flag set to true because remote virtual network has no GWs
  use_remote_gateways = false
}

resource "azurerm_virtual_network_peering" "hub_to_spoke1" {
  name                         = "peer-hub-to-spoke1"
  resource_group_name          = data.azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke1_to_spoke2" {
  name                         = "peer-spoke1-to-spoke2"
  resource_group_name          = data.azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.spoke1.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_linux_virtual_machine_scale_set" "spoke1" {
  name                            = "vmss-systemid-spoke1-1"
  resource_group_name             = data.azurerm_resource_group.rg.name
  location                        = local.location
  sku                             = "Standard_B4ms"
  instances                       = 2
  admin_username                  = "adminuser"
  admin_password                  = random_password.vmss_spoke1.result
  disable_password_authentication = false

  network_interface {
    name    = "eth0"
    primary = true
    ip_configuration {
      name                                   = "internal4"
      subnet_id                              = azurerm_subnet.spoke1_subnet1.id
      version                                = "IPv4"
      primary                                = true
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lb1_backend.id]
    }
    ip_configuration {
      name      = "internal6"
      subnet_id = azurerm_subnet.spoke1_subnet1.id
      version   = "IPv6"
      load_balancer_backend_address_pool_ids = [
        azurerm_lb_backend_address_pool.lb1_backend6.id,
        azurerm_lb_backend_address_pool.lb6_backend.id
      ]
    }
  }

  identity {
    type = "SystemAssigned"
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

resource "random_password" "vmss_spoke1" {
  length      = 16
  min_lower   = 4
  min_upper   = 4
  min_numeric = 4
  special     = false
}

output "vmss_spoke1_passwd" {
  value     = random_password.vmss_spoke1.result
  sensitive = true
}

resource "azurerm_role_assignment" "spoke1_vm" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_virtual_machine_scale_set.spoke1.identity[0].principal_id
}
