/* Storage reachable from Spoke2 via Service Endpoint

The Storage account has SAS access disabled, and Network ACL for public endpoint.
The UserManagedIdentity assigned to VM in Spoke2 has access to the Container. 

*/

resource "random_string" "strgeacct2" {
  length  = 8
  lower   = true
  special = false
  upper   = false
}

resource "azurerm_storage_account" "strgeacct2" {
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
    # Silent Terraform error if the ServiceEndpoint Microsoft.Storage is not in the Subnet
    virtual_network_subnet_ids = [azurerm_subnet.spoke2_subnet1.id]
    bypass                     = ["Metrics", "Logging", "AzureServices"]
  }

  min_tls_version = "TLS1_2"
}

resource "azurerm_storage_container" "container2" {
  name                  = "central-storage-2"
  storage_account_name  = azurerm_storage_account.strgeacct2.name
  container_access_type = "private" # No annonymous acccess
}

resource "azurerm_role_assignment" "robotme" {
  scope                = azurerm_storage_account.strgeacct2.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.robot_me.principal_id
}
