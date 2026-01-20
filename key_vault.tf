########$$$$$$$#######################
# Create SSH KEY PAIR FOR CCES Nodes #
###############$$$$$$#################

# Create RSA key of size 4096 bits
resource "tls_private_key" "cc-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_key_vault" "cc_key_vault" {
  name                        = var.azure_key_vault_name == "" ? "${var.cluster_name}" : var.azure_key_vault_name
  location                    = azurerm_resource_group.cc_rg.location
  resource_group_name         = azurerm_resource_group.cc_rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  tags = var.azure_tags
}

resource "azurerm_key_vault_access_policy" "cc_key_vault_access_policy_deployment_user" {
  key_vault_id = azurerm_key_vault.cc_key_vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = var.deployment_user_id

  key_permissions = [
    "Create",
    "Get",
  ]

  secret_permissions = [
    "Set",
    "Get",
    "Delete",
    "Purge",
    "Recover"
  ]
}

resource "azurerm_key_vault_secret" "cc_private_ssh_key" {
  name         = "${var.cluster_name}-ssh-private-key"
  value        = tls_private_key.cc-key.private_key_pem
  content_type = "SSH Key"
  key_vault_id = azurerm_key_vault.cc_key_vault.id

  depends_on = [
    azurerm_key_vault.cc_key_vault,
    azurerm_key_vault_access_policy.cc_key_vault_access_policy
  ]
}

resource "azurerm_ssh_public_key" "cc_public_ssh_key" {
  name                = "${var.cluster_name}-public-key"
  resource_group_name = azurerm_resource_group.cc_rg.name
  location            = azurerm_resource_group.cc_rg.location
  public_key          = tls_private_key.cc-key.public_key_openssh

  tags = var.azure_tags
}
