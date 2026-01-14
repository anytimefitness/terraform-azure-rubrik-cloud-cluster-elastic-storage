#####################################################
# Create the storage account and container for CCES #
#####################################################

resource "azurerm_storage_account" "cc_storage_account" {
  name                          = var.azure_sa_name
  resource_group_name           = azurerm_resource_group.cc_rg.name
  location                      = azurerm_resource_group.cc_rg.location
  account_tier                  = "Standard"
  account_replication_type      = var.azure_sa_replication_type
  public_network_access_enabled = true

  blob_properties {
    versioning_enabled = var.enableImmutability
  }

  tags = var.azure_tags
}

# Workaround until azurerm_storage_container supports setting the version level immutability option.
# See https://github.com/hashicorp/terraform-provider-azurerm/issues/21512 
# and https://github.com/hashicorp/terraform-provider-azurerm/issues/3722 for more details.

resource "azapi_resource" "cc_container" {
  type = "Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01"
  name = var.cluster_name

  # We append '/blobServices/default' to the storage_account.id see desc. above
  parent_id = "${azurerm_storage_account.cc_storage_account.id}/blobServices/default"

  body = {
    properties = {
      immutableStorageWithVersioning = {
        enabled = "${var.enableImmutability}"
      }
      publicAccess = "None"
    }
  }
}

# Note. this azapi_resource can be replaced with the "service_endpoints = ["Microsoft.Storage"]"
# option on the azurerm_subnet resource if the subnet is also created by Terraform.

resource "azapi_update_resource" "cces_subnet_storage_endpoint" {
  count       = var.azure_enable_subnet_storage_endpoint ? 1 : 0
  type        = "Microsoft.Network/virtualNetworks/subnets@2023-02-01"
  resource_id = data.azurerm_subnet.cces_subnet.id

  body = {
    properties = {
      serviceEndpoints = [{
        service = "Microsoft.Storage"
      }]
    }
  }
}

