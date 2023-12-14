/* Azure Network Monitoring

LogAnalyticsWorkspace and NetworkWatcher

*/

resource "azurerm_log_analytics_workspace" "law" {
  name                       = "law-1"
  location                   = data.azurerm_resource_group.rg.location
  resource_group_name        = data.azurerm_resource_group.rg.name
  sku                        = "PerGB2018"
  internet_ingestion_enabled = false
}

/*
resource "azurerm_network_watcher" "nw" {
  name                = "netwatch-1"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}


locals {
  logged_nsgs = {
    (azurerm_network_security_group.default_spoke1.name) = azurerm_network_security_group.default_spoke1.id
    (azurerm_network_security_group.default_spoke2.name) = azurerm_network_security_group.default_spoke2.id
  }
}

resource "azurerm_network_watcher_flow_log" "nsgs" {
  for_each = local.logged_nsgs

  network_watcher_name = azurerm_network_watcher.nw.name
  resource_group_name  = data.azurerm_resource_group.rg.name
  name                 = "nsgflowlog-${each.key}"

  network_security_group_id = each.value
  storage_account_id        = azurerm_storage_account.strgeacct2.id
  enabled                   = true

  retention_policy {
    enabled = true
    days    = 7
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.law.workspace_id
    workspace_region      = azurerm_log_analytics_workspace.law.location
    workspace_resource_id = azurerm_log_analytics_workspace.law.id
    interval_in_minutes   = 10
  }
}
*/