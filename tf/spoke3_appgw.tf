resource "azurerm_subnet_route_table_association" "spoke3_appgw" {
  subnet_id      = azurerm_subnet.spoke3_appgw.id
  route_table_id = azurerm_route_table.spoke3_appgw.id
}

resource "azurerm_subnet_network_security_group_association" "spoke3_appgw" {
  subnet_id                 = azurerm_subnet.spoke3_appgw.id
  network_security_group_id = azurerm_network_security_group.spoke3_appgw.id
}

resource "azurerm_network_security_group" "spoke3_appgw" {
  name                = "nsg-appgw-spoke-3"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name

  # https://learn.microsoft.com/en-us/azure/application-gateway/configuration-infrastructure
  security_rule {
    name                       = "http_s-allow-in"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges     = ["80", "443"]
    destination_address_prefixes    = azurerm_subnet.spoke3_appgw.address_prefixes
    source_address_prefix        = "Internet"
  }
  security_rule {
    name                       = "healtprobe-allow-in"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    destination_address_prefix = "*"
    source_address_prefix      = "GatewayManager"
  }
  security_rule {
    name                         = "lb-allow-in"
    priority                     = 130
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "*"
    source_address_prefix        = "AzureLoadBalancer"
    destination_address_prefix = "*"
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

resource "azurerm_virtual_network_peering" "spoke3_to_hub" {
  name                         = "peer-spoke3-to-hub"
  resource_group_name          = data.azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.spoke3.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  # cannot have UseRemoteGateway flag set to true because remote virtual network has no GWs
  use_remote_gateways = false
}

resource "azurerm_public_ip" "spoke3_appgw" {
  name                = "pubip-appgw-1"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_gateway#example-usage
resource "azurerm_user_assigned_identity" "spoke3_appgw" {
  location            = data.azurerm_resource_group.rg.location
  name                = "appgw-1"
  resource_group_name = data.azurerm_resource_group.rg.name
}

locals {
  backend_address_pool_name      = "bckendpool-appgw-1"
  frontend_ip_configuration_name = "frontend_appgw-1"
  http_setting_name              = "httpsetting-appgw-1"
  https_listener_name            = "listen-https-appgw-1"
  http_listener_name             = "listen-http-appgw-1"
  request_routing_rule_name      = "rqstrouting-appgw-1"
  redirect_configuration_name    = "rqstredirect-appgw-1"
}

resource "azurerm_application_gateway" "spoke3_appgw" {
  name                = "appgw-1"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "ip-configuration"
    subnet_id = azurerm_subnet.spoke3_appgw.id
  }

  frontend_port {
    name = "http"
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.spoke3_appgw.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 8080
    protocol              = "Http"
    request_timeout       = 20
  }

  http_listener {
    name                           = local.http_listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    priority                   = 9
    rule_type                  = "Basic"
    http_listener_name         = local.http_listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}