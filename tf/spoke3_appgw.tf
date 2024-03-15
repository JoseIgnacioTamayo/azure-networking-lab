/* External IPv4 AppGW in Spoke vNet

IPv4 Frontends listen for HTTP and HTTPS

SSL Offload termination at AppGw
HTTP to HTTPS permanent redirection at

It probes the Backends on TCP 8082
The Backends listen on TCP 8080-8082

*/


resource "azurerm_subnet_route_table_association" "AppGwSubnet" {
  subnet_id      = azurerm_subnet.AppGwSubnet.id
  route_table_id = azurerm_route_table.AppGwSubnet.id
}

resource "azurerm_subnet_network_security_group_association" "AppGwSubnet" {
  subnet_id                 = azurerm_subnet.AppGwSubnet.id
  network_security_group_id = azurerm_network_security_group.AppGwSubnet.id
}

resource "azurerm_route_table" "AppGwSubnet" {
  name                = "rt-appgw-spoke-3"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_network_security_group" "AppGwSubnet" {
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
    destination_address_prefix = "VirtualNetwork"
    source_address_prefix        = "Internet"
  }
  security_rule {
    name                       = "appgwmngr-allow-in"
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
  frontend_ip_configuration_name = "frontend_appgw-1" # SKU Standard_v2 is not allowed to change the name of an existing FrontendIpConfiguration
  frontend_80_name                 = "http"
  frontend_443_name                = "https"
  http_setting_name              = "httpsetting-appgw-1"
  https_listener_name            = "listen-https-appgw-1"
  http_listener_name             = "listen-http-appgw-1"
  request_routing_rule_name      = "rqstrouting-appgw-1"
  redirect_configuration_name    = "rqstredirect-appgw-1"
  ssl_certificate_name           = "sslcert-1"
  https_redirect_name = "redirect-appgw-1"
  http_probe_name = "http-probe-1"
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
    subnet_id = azurerm_subnet.AppGwSubnet.id
  }

  frontend_port {
    name = local.frontend_80_name
    port = 80
  }
  frontend_port {
    name = local.frontend_443_name
    port = 443
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
    port                  = 8080
    protocol              = "Http"
    request_timeout       = 30
    probe_name = local.http_probe_name
    pick_host_name_from_backend_address = true
  }

  http_listener {
    name                           = local.http_listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_80_name
    protocol                       = "Http"
  }
  http_listener {
    name                           = local.https_listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_443_name
    protocol                       = "Https"
    ssl_certificate_name = local.ssl_certificate_name
  }

  redirect_configuration {
          include_path         = true
          include_query_string = true
          name                 = local.https_redirect_name
          redirect_type        = "Permanent"
          target_listener_name    = local.https_listener_name
        }
  request_routing_rule {
    name                       = "rule-appgw-1"
    priority                   = 100
    rule_type                  = "Basic"
    http_listener_name         = local.http_listener_name
    redirect_configuration_name = local.https_redirect_name
  }
  request_routing_rule {
    name                       = "rule-appgw-2"
    priority                   = 110
    rule_type                  = "Basic"
    http_listener_name         = local.https_listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }

   probe {
    interval                                  = 30
    minimum_servers                           = 1
    name                                      = local.http_probe_name
    pick_host_name_from_backend_http_settings = true
    port                                      = 8082
    path = "/health"
    protocol                                  = "Http"
    timeout                                   = 30
    unhealthy_threshold                       = 3
  }

  ssl_certificate {
    name = local.ssl_certificate_name
    data = filebase64(var.ssl_cert_pfx_file)
    password = var.ssl_cert_pfx_passwd
  }
}