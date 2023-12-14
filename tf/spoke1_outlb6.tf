/* External LB in Spoke vNet, for IPv6 Outbound Access
*/

resource "azurerm_public_ip" "lb6" {
  name                = "pubip-lb6-1"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv6"
}

resource "azurerm_lb" "lb6" {
  name                = "lb-spoke1-2"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb6.id
  }
}

resource "azurerm_lb_backend_address_pool" "lb6_backend" {
  name            = "lbbckend-lbspoke1-3"
  loadbalancer_id = azurerm_lb.lb6.id
}

resource "azurerm_lb_outbound_rule" "lb6" {
  name                     = "lboutnat-lb6-1"
  loadbalancer_id          = azurerm_lb.lb6.id
  protocol                 = "All"
  enable_tcp_reset         = true
  allocated_outbound_ports = 0
  backend_address_pool_id  = azurerm_lb_backend_address_pool.lb6_backend.id

  frontend_ip_configuration {
    name = "PublicIPAddress"
  }
}
