####################################
# Create a Resource Group for CCES #
####################################

resource "azurerm_resource_group" "cc_rg" {
  name     = var.azure_resource_group
  location = var.azure_location

  tags = var.azure_tags
}

######################################
# Bootstrap the Rubrik Cloud Cluster #
###########################k##########

resource "time_sleep" "wait_for_nodes_to_boot" {
  create_duration = "300s"

  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.cces_data_disk,
    azurerm_virtual_machine_data_disk_attachment.cces_metadata_disk,
    azurerm_virtual_machine_data_disk_attachment.cces_cache_disk,
  ]
}

resource "polaris_cdm_bootstrap_cces_azure" "bootstrap_cces_azure" {
  count = var.skip_bootstrap_status_check ? 0 : 1

  cluster_name           = var.cluster_name
  cluster_nodes          = zipmap(local.cluster_node_names, local.cluster_node_ips)
  admin_email            = var.admin_email
  admin_password         = var.admin_password
  management_gateway     = cidrhost(data.azurerm_subnet.cces_subnet.address_prefixes.0, 1)
  management_subnet_mask = cidrnetmask(data.azurerm_subnet.cces_subnet.address_prefixes.0)
  dns_search_domain      = var.dns_search_domain
  dns_name_servers       = var.dns_name_servers
  ntp_server1_name       = var.ntp_server1_name
  ntp_server2_name       = var.ntp_server2_name
  connection_string      = azurerm_storage_account.cc_storage_account.primary_connection_string
  container_name         = var.cluster_name
  enable_immutability    = var.enableImmutability
  timeout                = var.timeout
  depends_on             = [time_sleep.wait_for_nodes_to_boot]
  wait_for_completion    = false
}

##############################################
# Register the Rubrik Cloud Cluster with RSC #
##############################################

resource "polaris_cdm_registration" "cces_azure_registration" {
  count                   = var.register_cluster_with_rsc ? 1 : 0
  admin_password          = var.admin_password
  cluster_name            = var.cluster_name
  cluster_node_ip_address = local.cluster_node_ips[0]
  depends_on              = [time_sleep.wait_for_nodes_to_boot]
}
