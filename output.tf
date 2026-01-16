locals {
  key_vault_secret_elements = split("/", azurerm_key_vault_secret.cc_private_ssh_key.id)
  key_vault_elements        = split("/", azurerm_key_vault.cc_key_vault.id)
}

output "rubrik_cloud_cluster_ip_addresses" {
  value = local.cluster_node_ips
}

output "key_vault_get_ssh_key_command" {
  value = "az keyvault secret show --name ${element(local.key_vault_secret_elements, length(local.key_vault_secret_elements) - 2)} --vault-name ${element(local.key_vault_elements, length(local.key_vault_elements) - 1)}  --query value -o tsv"
}
