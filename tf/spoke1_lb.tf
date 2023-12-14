/* Internal dual-stack LB in Spoke vNet

IPv4 and IPv6 Frontends listen at TCP80
It probes the Backends on TCP8080
The Backends listen on TCP8080 for IPv4 and TCP8081 for IPv6

*/

resource "azurerm_lb" "lb1" {
  name                = "lb-spoke1-1"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "PrivateIPv4Address"
    private_ip_address_allocation = "Static"
    subnet_id                     = azurerm_subnet.spoke1_subnet1.id
    private_ip_address_version    = "IPv4"
    private_ip_address            = local.lb1_intenal_vip
  }
  frontend_ip_configuration {
    name                          = "PrivateIPv6Address"
    private_ip_address_allocation = "Static"
    subnet_id                     = azurerm_subnet.spoke1_subnet1.id
    private_ip_address_version    = "IPv6"
    private_ip_address            = local.lb1_intenal_vip6
  }
}

resource "azurerm_lb_rule" "lb1_rule4" {
  loadbalancer_id                = azurerm_lb.lb1.id
  name                           = "lbrule-lbspoke1-1"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 8080
  frontend_ip_configuration_name = "PrivateIPv4Address"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb1_backend.id]
}

resource "azurerm_lb_rule" "lb1_rule6" {
  loadbalancer_id                = azurerm_lb.lb1.id
  name                           = "lbrule-lbspoke1-2"
  protocol                       = "Tcp" # If ALL, Ports must be 0 (Any)
  frontend_port                  = 80
  backend_port                   = 8081
  frontend_ip_configuration_name = "PrivateIPv6Address"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb1_backend6.id]
}

resource "azurerm_lb_backend_address_pool" "lb1_backend" {
  name            = "lbbckend-lbspoke1-1"
  loadbalancer_id = azurerm_lb.lb1.id
}

resource "azurerm_lb_backend_address_pool" "lb1_backend6" {
  name            = "lbbckend-lbspoke1-2"
  loadbalancer_id = azurerm_lb.lb1.id
}

resource "azurerm_lb_probe" "lb1" {
  loadbalancer_id = azurerm_lb.lb1.id
  name            = "lbprobe-lbspoke1-1"
  port            = 8080
  protocol        = "Tcp"
}

