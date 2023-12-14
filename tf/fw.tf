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

resource "azurerm_firewall_application_rule_collection" "allow_internet" {
  name                = "fwapprules-1"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = data.azurerm_resource_group.rg.name
  priority            = 1100
  action              = "Allow"

  rule {
    name             = "Vnet2Internets"
    source_addresses = ["10.0.0.0/14"]
    target_fqdns     = ["www.google.com", "*.microsoft.com"]

    protocol {
      port = 80
      type = "Http"
    }
    protocol {
      port = 8080
      type = "Http"
    }
    protocol {
      port = 443
      type = "Https"
    }
  }

  # https://learn.microsoft.com/en-us/cli/azure/azure-cli-endpoints?tabs=azure-cloud
  # Domains needed for Azure Cli
  rule {
    name             = "Vnet2AzCli"
    source_addresses = ["10.0.0.0/14"]
    target_fqdns     = ["*.core.windows.net", "*.azure.com", "*.azure.net", "aka.ms"]
    protocol {
      port = 443
      type = "Https"
    }
  }

  rule {
    name             = "Vnet2Ubuntu"
    source_addresses = ["10.0.0.0/14"]
    target_fqdns     = ["azure.archive.ubuntu.com"]
    protocol {
      port = 80
      type = "Http"
    }
    protocol {
      port = 443
      type = "Https"
    }
  }
}

resource "azurerm_firewall_network_rule_collection" "allow_vnet" {
  name                = "fwnetrules-allow-vnet-1"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = data.azurerm_resource_group.rg.name
  priority            = 1200
  action              = "Allow"

  rule {
    name                  = "vNet2vNet_tcp"
    source_addresses      = ["10.0.0.0/14"]
    destination_addresses = ["10.0.0.0/14"]
    destination_ports     = ["443", "22", "3389", "80"]
    protocols             = ["TCP"]
  }
  rule {
    name                  = "vNet2vNet_icmp"
    source_addresses      = ["10.0.0.0/14"]
    destination_addresses = ["10.0.0.0/14"]
    destination_ports     = ["*"]
    protocols             = ["ICMP"]
  }
}

resource "azurerm_firewall_network_rule_collection" "allow_onprem" {
  name                = "fwnetrules-allow-onprem-1"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = data.azurerm_resource_group.rg.name
  priority            = 1220
  action              = "Allow"

  rule {
    name                  = "vNet2onPrem_tcp"
    source_addresses      = ["10.0.1.0/24"]
    destination_addresses = ["10.99.0.0/23"]
    destination_ports     = ["443", "22"]
    protocols             = ["TCP"]
  }
  rule {
    name                  = "onPrem2vNet_tcp"
    source_addresses      = ["10.99.0.0/23"]
    destination_addresses = ["10.0.2.0/24"]
    destination_ports     = ["80"]
    protocols             = ["TCP"]
  }
  rule {
    name                  = "vNet2onPrem_icmp"
    source_addresses      = ["10.99.0.0/23", "10.0.0.0/14"]
    destination_addresses = ["10.0.0.0/14", "10.99.0.0/23"]
    destination_ports     = ["*"]
    protocols             = ["ICMP"]
  }
}

resource "azurerm_firewall_nat_rule_collection" "fwnat-rules" {
  name                = "fwnatrules-dnat-lb2-1"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = data.azurerm_resource_group.rg.name
  priority            = 1100
  action              = "Dnat"

  rule {
    name                  = "dnat_lb2"
    destination_ports     = ["8080"]
    source_addresses      = ["0.0.0.0/0"]
    destination_addresses = [azurerm_public_ip.pupip_fw.ip_address]
    translated_port       = 8080
    translated_address    = local.lb1_intenal_vip
    protocols             = ["TCP"]
  }
}
