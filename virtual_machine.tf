############################################
# Launch the Rubrik Cloud Cluster ES Nodes #
######################k#####################

resource "azurerm_network_interface" "cces_nic" {
  for_each                       = toset(local.cluster_node_names)
  name                           = "${each.value}-nic"
  resource_group_name            = azurerm_resource_group.cc_rg.name
  location                       = azurerm_resource_group.cc_rg.location
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = each.value
    subnet_id                     = data.azurerm_subnet.cces_subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.azure_tags

}

resource "azurerm_management_lock" "cces_nic" {
  for_each   = var.azure_resource_lock == true ? toset(local.cluster_node_names) : []
  name       = "${each.value}-nic"
  scope      = azurerm_network_interface.cces_nic[each.value].id
  lock_level = "CanNotDelete"
  notes      = "Locked because this is a critical resource."
}

# User needs to make sure that the marketplace agreement for CCES has been accepted before this runs.

resource "azurerm_linux_virtual_machine" "cces_node" {
  for_each              = toset(local.cluster_node_names)
  name                  = "${each.value}-vm"
  location              = azurerm_resource_group.cc_rg.location
  resource_group_name   = azurerm_resource_group.cc_rg.name
  network_interface_ids = [azurerm_network_interface.cces_nic[each.value].id]
  size                  = var.azure_cces_vm_size
  admin_username        = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.cc-key.public_key_openssh
  }

  source_image_reference {
    publisher = "rubrik-inc"
    offer     = "rubrik-data-protection"
    sku       = var.azure_cces_sku
    version   = var.azure_cces_version
  }

  os_disk {
    caching              = "None"
    storage_account_type = "Premium_LRS"
  }

  plan {
    name      = var.azure_cces_plan_name
    publisher = "rubrik-inc"
    product   = "rubrik-data-protection"
  }

  lifecycle {
    ignore_changes = [
      identity
    ]
  }

  tags = var.azure_tags

}

resource "azurerm_management_lock" "cces_node" {
  for_each   = var.azure_resource_lock == true ? toset(local.cluster_node_names) : []
  name       = "${each.value}-vm"
  scope      = azurerm_linux_virtual_machine.cces_node[each.value].id
  lock_level = "CanNotDelete"
  notes      = "Locked because this is a critical resource."
}

resource "azurerm_managed_disk" "cces_data_disk" {
  for_each             = toset(local.cluster_node_names)
  name                 = "${each.value}-disk"
  location             = azurerm_resource_group.cc_rg.location
  resource_group_name  = azurerm_resource_group.cc_rg.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = "512"
  tags                 = var.azure_tags
}

resource "azurerm_management_lock" "cces_data_disk" {
  for_each   = var.azure_resource_lock == true ? toset(local.cluster_node_names) : []
  name       = "${each.value}-disk"
  scope      = azurerm_managed_disk.cces_data_disk[each.value].id
  lock_level = "CanNotDelete"
  notes      = "Locked because this is a critical resource."
}

resource "azurerm_virtual_machine_data_disk_attachment" "cces_data_disk" {
  for_each           = toset(local.cluster_node_names)
  managed_disk_id    = azurerm_managed_disk.cces_data_disk[each.value].id
  virtual_machine_id = azurerm_linux_virtual_machine.cces_node[each.value].id
  lun                = "0"
  caching            = "ReadWrite"
}

# Create 2 additional disks, one for metadata and for cache, per cluster node
# for CDM version 9.2.2 and later.

resource "azurerm_managed_disk" "cces_metadata_disk" {
  for_each             = local.split_disk ? toset(local.cluster_node_names) : []
  name                 = "${each.value}-metadata-disk"
  location             = azurerm_resource_group.cc_rg.location
  resource_group_name  = azurerm_resource_group.cc_rg.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = "132"
  tags                 = var.azure_tags
}

resource "azurerm_management_lock" "cces_metadata_disk" {
  for_each   = local.split_disk && var.azure_resource_lock ? toset(local.cluster_node_names) : []
  name       = "${each.value}-metadata-disk"
  scope      = azurerm_managed_disk.cces_metadata_disk[each.value].id
  lock_level = "CanNotDelete"
  notes      = "Locked because this is a critical resource."
}

resource "azurerm_virtual_machine_data_disk_attachment" "cces_metadata_disk" {
  for_each           = local.split_disk ? toset(local.cluster_node_names) : []
  managed_disk_id    = azurerm_managed_disk.cces_metadata_disk[each.value].id
  virtual_machine_id = azurerm_linux_virtual_machine.cces_node[each.value].id
  lun                = "1"
  caching            = "ReadWrite"
}

resource "azurerm_managed_disk" "cces_cache_disk" {
  for_each             = local.split_disk ? toset(local.cluster_node_names) : []
  name                 = "${each.value}-cache-disk"
  location             = azurerm_resource_group.cc_rg.location
  resource_group_name  = azurerm_resource_group.cc_rg.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = "206"
  tags                 = var.azure_tags
}

resource "azurerm_management_lock" "cces_cache_disk" {
  for_each   = local.split_disk && var.azure_resource_lock ? toset(local.cluster_node_names) : []
  name       = "${each.value}-cache-disk"
  scope      = azurerm_managed_disk.cces_cache_disk[each.value].id
  lock_level = "CanNotDelete"
  notes      = "Locked because this is a critical resource."
}

resource "azurerm_virtual_machine_data_disk_attachment" "cces_cache_disk" {
  for_each           = local.split_disk ? toset(local.cluster_node_names) : []
  managed_disk_id    = azurerm_managed_disk.cces_cache_disk[each.value].id
  virtual_machine_id = azurerm_linux_virtual_machine.cces_node[each.value].id
  lun                = "2"
  caching            = "ReadWrite"
}
