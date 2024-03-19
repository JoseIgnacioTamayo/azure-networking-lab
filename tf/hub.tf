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
  address_prefixes     = ["10.0.0.0/27"]
}

resource "azurerm_subnet" "AzureBastionSubnet" {
  name                 = "AzureBastionSubnet"
  virtual_network_name = azurerm_virtual_network.hub.name
  resource_group_name  = data.azurerm_resource_group.rg.name
  address_prefixes     = ["10.0.0.192/26"] # Subnet must be /26 or larger
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

