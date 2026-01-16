##################
# Data Gathering #
##################

data "azurerm_subscription" "current" {}

data "azurerm_subnet" "cces_subnet" {
  name                 = var.azure_subnet_name
  virtual_network_name = var.azure_vnet_name
  resource_group_name  = var.azure_vnet_rg_name
}

data "azurerm_client_config" "current" {}
