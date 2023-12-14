/* The Hub

Has AzureFirewall, VPNGateway and Bastion

*/

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-1"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = local.location
  address_space       = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "GatewaySubnet" {
  name                 = "GatewaySubnet"
  virtual_network_name = azurerm_virtual_network.hub.name
  resource_group_name  = data.azurerm_resource_group.rg.name
  address_prefixes     = ["10.0.0.224/27"]
}

resource "azurerm_subnet" "AzureBastionSubnet" {
  name                 = "AzureBastionSubnet"
  virtual_network_name = azurerm_virtual_network.hub.name
  resource_group_name  = data.azurerm_resource_group.rg.name
  address_prefixes     = ["10.0.0.192/27"]
}

resource "azurerm_subnet" "AzureFirewallSubnet" {
  name                 = "AzureFirewallSubnet"
  virtual_network_name = azurerm_virtual_network.hub.name
  resource_group_name  = data.azurerm_resource_group.rg.name
  address_prefixes     = ["10.0.0.128/26"] # Subnet must be /26 or larger
}

resource "azurerm_subnet" "AzureFirewallManagementSubnet" {
  name                 = "AzureFirewallManagementSubnet"
  virtual_network_name = azurerm_virtual_network.hub.name
  resource_group_name  = data.azurerm_resource_group.rg.name
  address_prefixes     = ["10.0.0.64/26"] # Subnet must be /26 or larger
}

resource "azurerm_route_table" "gw" {
  name                          = "rt-gateway-1"
  location                      = local.location
  resource_group_name           = data.azurerm_resource_group.rg.name
  disable_bgp_route_propagation = false

  # VirtualNetworkGatewaySubnetRouteTableCannotHaveDefaultRoute
  route {
    name                   = "spoke-1"
    address_prefix         = azurerm_virtual_network.spoke1.address_space.0
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
  }
  route {
    name                   = "spoke-2"
    address_prefix         = azurerm_virtual_network.spoke2.address_space.0
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "gw" {
  subnet_id      = azurerm_subnet.GatewaySubnet.id
  route_table_id = azurerm_route_table.gw.id
}

resource "azurerm_route_table" "fw" {
  name                          = "rt-fw-1"
  location                      = local.location
  resource_group_name           = data.azurerm_resource_group.rg.name
  disable_bgp_route_propagation = false
}

resource "azurerm_subnet_route_table_association" "fw" {
  subnet_id      = azurerm_subnet.AzureFirewallSubnet.id
  route_table_id = azurerm_route_table.fw.id
}

resource "azurerm_public_ip" "bastion" {
  name                = "pubip-bastion-1"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard" # Bastion Host Public IP MUST be Standard
}

resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-1"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "Basic"

  ip_configuration {
    name                 = "ip_config"
    subnet_id            = azurerm_subnet.AzureBastionSubnet.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_network_security_group" "bastion" {
  name                = "nsg-bastion-1"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name

  # NetworkSecurityGroupNotCompliantForAzureBastionSubnet
  # The Bastion Subnet needs specific rules in the NSG
  security_rule {
    name                       = "ingress-internet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "ingress-gwmanager"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "ingress-bastion"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                       = "ingress-lb"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "ingress-deny"
    priority                   = 199
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "egress-ssh-rdp"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                       = "egress-bastion"
    priority                   = 201
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                       = "egress-azure"
    priority                   = 202
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }
  security_rule {
    name                       = "egress-deny"
    priority                   = 299
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "Bastion" {
  subnet_id                 = azurerm_subnet.AzureBastionSubnet.id
  network_security_group_id = azurerm_network_security_group.bastion.id
}
