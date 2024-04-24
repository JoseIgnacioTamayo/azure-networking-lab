/* Hub VPNGateway connected to onPrem via S2S VPN
*/

resource "random_password" "vpn_psk" {
  length      = 32
  min_lower   = 2
  min_upper   = 4
  min_numeric = 4
  min_special = 2
}

resource "azurerm_public_ip" "hub_vpngw" {
  name                = "pubip-vpngw-1"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name

  allocation_method = "Dynamic"
  sku               = "Basic"
}

resource "azurerm_virtual_network_gateway" "hub" {
  name                = "vpngw-hub-1"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = true
  sku           = "VpnGw1"

  ip_configuration {
    name                          = "ipConfig"
    public_ip_address_id          = azurerm_public_ip.hub_vpngw.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.GatewaySubnet.id
  }

  bgp_settings {
    asn = 65599
    peering_addresses {
      apipa_addresses = ["169.254.21.99", "169.254.21.98"]
    }
  }
}

resource "azurerm_virtual_network_gateway_connection" "hub_to_onprem" {
  name                = "conn-hub-to-onprem-1"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.hub.id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.onprem.id

  shared_key = random_password.vpn_psk.result

  enable_bgp = true

  ipsec_policy {
    dh_group         = "DHGroup2048"
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    ipsec_encryption = "AES256"
    ipsec_integrity  = "SHA256"
    pfs_group        = "ECP384"

  }
}
