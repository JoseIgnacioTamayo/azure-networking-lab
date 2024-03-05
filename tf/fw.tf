/* Azure Firewall Basic, sitting in the Hub

Uses Management Subnet
Sends Diagnostics to LogAnalyticsWorkspace and StorageAccount
Uses Classic Rules (No Policy)

*/

resource "azurerm_public_ip" "pupip_fw" {
  name                = "pubip-fw-1"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "pupip_fwmgmt" {
  name                = "pubip-fwmgmt-1"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "fw" {
  name                = "azfw-1"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic"

  # ip_configuration names must be unique
  ip_configuration {
    name                 = "public-ip-config"
    subnet_id            = azurerm_subnet.AzureFirewallSubnet.id
    public_ip_address_id = azurerm_public_ip.pupip_fw.id
  }

  management_ip_configuration {
    name                 = "mgmt-ip-config"
    subnet_id            = azurerm_subnet.AzureFirewallManagementSubnet.id
    public_ip_address_id = azurerm_public_ip.pupip_fwmgmt.id
  }
}

/*
resource "azurerm_monitor_diagnostic_setting" "fwdiag_storage" {
  name               = "diagsettgs-storage-azfw-1"
  target_resource_id = azurerm_firewall.fw.id
  storage_account_id = azurerm_storage_account.strgeacct2.id

  enabled_log {
    category = "AzureFirewallApplicationRule"
  }
  enabled_log {
    category = "AzureFirewallNetworkRule"
  }
  enabled_log {
    category = "AZFWApplicationRule"
  }
  enabled_log {
    category = "AZFWNetworkRule"
  }
  metric {
    category = "AllMetrics"
  }
}
*/

resource "azurerm_monitor_diagnostic_setting" "fwdiag_law" {
  name                           = "diagsettgs-law-azfw-1"
  target_resource_id             = azurerm_firewall.fw.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.law.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "AzureFirewallNetworkRule"
  }
  enabled_log {
    category = "AzureFirewallApplicationRule"
  }

  metric {
    category = "AllMetrics"
    enabled  = false
  }
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