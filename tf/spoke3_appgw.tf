/* External IPv4 AppGW in Spoke vNet

IPv4 Frontends listen for HTTP and HTTPS

SSL Offload termination at AppGw

AppGw has a Detection WAF Policy with OWASP 3.2 managed rules.

HTTP to HTTPS permanent redirection. Keeps the path, resets the QueryString
 > http://<ip>/some/path?nice_query=keep  >> Found >> https://<ip>/some/path

HTTP Rewrite rules with contidion
 > /<path>?replace=me gets replaced by /<path>?replace=you

HTTP Reroute to other Service
 > /download is directed to TCP 8081 with path /services/upload/v1
 > /secret is directed to TCP 8081 (keeps path). This is protected by a restrictive WAF policy

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
    destination_port_ranges    = ["80", "443"]
    destination_address_prefix = "VirtualNetwork"
    source_address_prefix      = "Internet"
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
    name                       = "lb-allow-in"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
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

locals {
  backend_address_pool_name      = "bckendpool-appgw-1"
  frontend_ip_configuration_name = "frontend-appgw-1" # SKU Standard_v2 is not allowed to change the name of an existing FrontendIpConfiguration
  frontend_80_name               = "http"
  frontend_443_name              = "https"
  http8080_setting_name          = "httpsetting-appgw-1"
  http8081path_setting_name      = "httpsetting-appgw-2"
  http8081_setting_name          = "httpsetting-appgw-3"
  https_listener_name            = "listen-https-appgw-1"
  http_listener_name             = "listen-http-appgw-1"
  ssl_certificate_name           = "sslcert-1"
  https_redirect_name            = "redirect-appgw-1"
  http_probe_name                = "http-probe-1"
  rewrite_rule_set_name          = "rewrite-appgw-1"
  rule_redirect_name             = "rule-appgw-1"
  rule_servepaths_name           = "rule-appgw-2"
  urlmap_name                    = "urlmap-appgw-1"
}

resource "azurerm_application_gateway" "spoke3_appgw" {
  name                = "appgw-1"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  waf_configuration {
    enabled            = false
    firewall_mode      = "Detection"
    rule_set_type      = "OWASP"
    rule_set_version   = "3.2"
    request_body_check = false
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
    name         = local.backend_address_pool_name
    ip_addresses = azurerm_linux_virtual_machine.spoke3.private_ip_addresses
  }

  backend_http_settings {
    name                                = local.http8080_setting_name
    cookie_based_affinity               = "Disabled"
    port                                = 8080
    protocol                            = "Http"
    request_timeout                     = 30
    probe_name                          = local.http_probe_name
    pick_host_name_from_backend_address = true
  }
  backend_http_settings {
    name                                = local.http8081path_setting_name
    cookie_based_affinity               = "Disabled"
    port                                = 8081
    protocol                            = "Http"
    request_timeout                     = 30
    pick_host_name_from_backend_address = true
    path                                = "/services/upload/v1"
  }
  backend_http_settings {
    name                                = local.http8081_setting_name
    cookie_based_affinity               = "Disabled"
    port                                = 8081
    protocol                            = "Http"
    request_timeout                     = 30
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
    ssl_certificate_name           = local.ssl_certificate_name
  }

  redirect_configuration {
    include_path         = true
    include_query_string = false
    name                 = local.https_redirect_name
    redirect_type        = "Found"
    target_listener_name = local.https_listener_name
  }
  request_routing_rule {
    name                        = local.rule_redirect_name
    priority                    = 100
    rule_type                   = "Basic"
    http_listener_name          = local.http_listener_name
    redirect_configuration_name = local.https_redirect_name
  }
  request_routing_rule {
    name               = local.rule_servepaths_name
    priority           = 110
    rule_type          = "PathBasedRouting"
    http_listener_name = local.https_listener_name
    url_path_map_name  = local.urlmap_name
  }

  rewrite_rule_set {
    name = local.rewrite_rule_set_name
    rewrite_rule {
      name          = "rewrite-1"
      rule_sequence = 100
      condition {
        ignore_case = true
        pattern     = "replace=me"
        variable    = "var_query_string"
      }
      url {
        components   = "query_string_only"
        query_string = "replace=you"
        reroute      = false
      }
    }
  }

  probe {
    interval                                  = 30
    minimum_servers                           = 1
    name                                      = local.http_probe_name
    pick_host_name_from_backend_http_settings = true
    port                                      = 8082
    path                                      = "/health"
    protocol                                  = "Http"
    timeout                                   = 30
    unhealthy_threshold                       = 3
  }

  ssl_certificate {
    name     = local.ssl_certificate_name
    data     = filebase64(var.ssl_cert_pfx_file)
    password = var.ssl_cert_pfx_passwd
  }

  url_path_map {
    default_backend_address_pool_name  = local.backend_address_pool_name
    default_backend_http_settings_name = local.http8080_setting_name
    default_rewrite_rule_set_name      = local.rewrite_rule_set_name
    name                               = local.urlmap_name
    path_rule {
      backend_address_pool_name  = local.backend_address_pool_name
      backend_http_settings_name = local.http8081path_setting_name
      name                       = "upload-appgw-1"
      paths = [
        "/download",
      ]
    }
    path_rule {
      backend_address_pool_name  = local.backend_address_pool_name
      backend_http_settings_name = local.http8081_setting_name
      name                       = "secret-appgw-1"
      # See spoke3_waf.tf
      firewall_policy_id         = azurerm_web_application_firewall_policy.spoke3_appgw.id
      paths = [
        "/secret",
      ]
    }
  }
}
