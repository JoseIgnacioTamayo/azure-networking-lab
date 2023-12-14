locals {
  location = "switzerlandnorth"

  # IP Address for LB.
  # This allows to deploy FW Rules and LB independently.
  lb1_intenal_vip  = "10.0.1.22"
  lb1_intenal_vip6 = "fd00:1::ff"
}

data "azurerm_resource_group" "rg" {
  name = var.rg_name
}

data "azurerm_client_config" "current" {
}

# User Managed Identity to assign to VMs
resource "azurerm_user_assigned_identity" "robot_me" {
  location            = data.azurerm_resource_group.rg.location
  name                = "robot-1"
  resource_group_name = data.azurerm_resource_group.rg.name
}

/*
# Allow me to play with StorageAccounts
resource "azurerm_role_assignment" "me_data_owner" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = data.azurerm_client_config.current.client_id
}
*/
