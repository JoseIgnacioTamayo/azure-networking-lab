/* OnPrem Network connected to Hub via S2S VPN

VPNGateway with Connection to Hub

VM in a subnet (admin password as output), accesible only for spoke1_subnet1

*/

resource "azurerm_virtual_network" "onprem" {
  name                = "vnet-onprem-1"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = local.location
  address_space       = ["10.99.0.0/23"]
}

resource "azurerm_subnet" "onprem" {
  name                 = "snet-onprem-1"
  virtual_network_name = azurerm_virtual_network.onprem.name
  resource_group_name  = data.azurerm_resource_group.rg.name
  address_prefixes     = ["10.99.0.0/26"]
}

resource "azurerm_subnet" "GatewaySubnet_onprem" {
  name                 = "GatewaySubnet"
  virtual_network_name = azurerm_virtual_network.onprem.name
  resource_group_name  = data.azurerm_resource_group.rg.name
  address_prefixes     = ["10.99.1.224/27"]
}

resource "azurerm_route_table" "rt_onprem" {
  name                          = "rt-gateway-onprem-1"
  location                      = local.location
  resource_group_name           = data.azurerm_resource_group.rg.name
  disable_bgp_route_propagation = false
}

resource "azurerm_subnet_route_table_association" "rt_onprem" {
  subnet_id      = azurerm_subnet.GatewaySubnet_onprem.id
  route_table_id = azurerm_route_table.rt_onprem.id
}

resource "random_password" "onprem_adminuser" {
  length      = 8
  min_lower   = 2
  min_upper   = 3
  min_numeric = 3
  special     = false
}

resource "azurerm_public_ip" "onprem_vpngw" {
  name                = "pubip-vpngw-onprem-1"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

resource "azurerm_virtual_network_gateway" "onprem" {
  name                = "vpngw-onprem-1"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = true
  sku           = "VpnGw1"

  ip_configuration {
    name                          = "ipConfig"
    public_ip_address_id          = azurerm_public_ip.onprem_vpngw.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.GatewaySubnet_onprem.id
  }

  bgp_settings {
    asn = 65588
    peering_addresses {
      apipa_addresses = ["169.254.22.88", "169.254.22.89"]
    }
  }
}

resource "azurerm_virtual_network_gateway_connection" "onprem_to_hub" {
  name                = "conn-onprem-to-hub-1"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name

  type                            = "Vnet2Vnet"
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.hub.id
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.onprem.id

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

resource "azurerm_network_security_group" "onprem_default" {
  name                = "nsg-default-onprem-1"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "ingress-allow-spoke"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefixes    = [azurerm_subnet.spoke1_subnet1.address_prefixes[0]]
    destination_address_prefix = "VirtualNetwork"
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
    name                       = "egress-vnet"
    priority                   = 201
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
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

resource "azurerm_subnet_network_security_group_association" "onprem_default" {
  subnet_id                 = azurerm_subnet.onprem.id
  network_security_group_id = azurerm_network_security_group.onprem_default.id
}


resource "azurerm_network_interface" "onprem_vm" {
  name                = "nic-onprem-1"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = local.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.onprem.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "onprem_vm" {
  name                = "vm-onprem-1"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = local.location
  size                = "Standard_B4ms"
  admin_username      = "adminuser"

  admin_password = random_password.onprem_adminuser.result

  disable_password_authentication = false # tfsec:ignore:disable-password-authentication
  network_interface_ids = [
    azurerm_network_interface.onprem_vm.id,
  ]

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

output "onprem_adminuser" {
  value     = random_password.onprem_adminuser.result
  sensitive = true
}