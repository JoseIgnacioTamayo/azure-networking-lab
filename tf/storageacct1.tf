/* Storage reachable from Spoke1 via Private Endpoint in Hub

The Storage account has SAS access disabled, and Network ACL for public endpoint.
The Private Endpoint is deployed in the Hub, in spoke1_subnet1.
The Private DNS Zone is linked to Hub and Spoke1

*/

resource "random_string" "strgeacct1" {
  length  = 8
  lower   = true
  special = false
}

resource "azurerm_storage_account" "strgeacct1" {
  name                          = substr("strgeacctlab${random_string.strgeacct2.result}", 0, 24)
  resource_group_name           = data.azurerm_resource_group.rg.name
  location                      = data.azurerm_resource_group.rg.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  shared_access_key_enabled     = false
  public_network_access_enabled = true

  # This FW rules allows requests to the PUBLIC Endpoint. By disabling it, only private access is possible.
  # This blocks even TF from manipulating it via Public IP.
  network_rules {
    default_action = "Deny"
    ip_rules       = [var.public_ip_range_allow_storage]
    bypass         = ["Logging", "Metrics", "AzureServices"]
  }



  min_tls_version = "TLS1_2"
}

resource "azurerm_storage_container" "container1" {
  name                  = "central-storage-1"
  storage_account_name  = azurerm_storage_account.strgeacct1.name
  container_access_type = "private" # No annonymous acccess
}

# Private DNS Zone and Links to client vNets

resource "azurerm_private_dns_zone" "blob_core" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "privdns_blobcore_spoke1" {
  name                  = "vnlk-blobcorewindowsnet-spoke1-1"
  resource_group_name   = data.azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.blob_core.name
  virtual_network_id    = azurerm_virtual_network.spoke1.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "privdns_blobcore_hub" {
  name                  = "vnlk-blobcorewindowsnet-hub-1"
  resource_group_name   = data.azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.blob_core.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}

resource "azurerm_private_dns_a_record" "strgeacct1" {
  name                = "privdns-storage-1"
  resource_group_name = data.azurerm_resource_group.rg.name
  zone_name           = azurerm_private_dns_zone.blob_core.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.strgeacct1.private_service_connection.0.private_ip_address]
}

resource "azurerm_private_endpoint" "strgeacct1" {
  name                = "privendpt-storage-hub-1"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.spoke1_subnet1.id

  private_service_connection {
    name                           = "privsrcconn-storage-hub-1"
    private_connection_resource_id = azurerm_storage_account.strgeacct1.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  # This avoid the need to update A records in the Private Zone when changes
  private_dns_zone_group {
    name                 = "privdnszonegrp-storage-1"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob_core.id]
  }
}
