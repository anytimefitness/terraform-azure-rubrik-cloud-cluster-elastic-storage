#############################
# Dynamic Variable Creation #
#############################

locals {
  enableImmutability = var.enableImmutability == true ? 1 : 0
  cluster_node_names = formatlist("${var.cluster_name}-%02s", range(1, var.number_of_nodes + 1))
  cluster_node_ips   = [for i in azurerm_linux_virtual_machine.cces_node : i.private_ip_address]

  # Regular expressions parsing the CCES SKU and version. Note, version can be
  # either a version number or latest.
  sku_regex     = "^rubrik-cdm-(\\d+)$"
  version_regex = "^(\\d+).(\\d+).(\\d+)$|^(latest)$"

  # Extract the major, minor and maintenance version numbers from the CCES SKU
  # and version strings.
  major_minor_version = parseint(regex(local.sku_regex, var.azure_cces_sku)[0], 10)
  maint_patch_build   = regex(local.version_regex, var.azure_cces_version)
  maint_version       = local.maint_patch_build[0] == null ? 0 : parseint(local.maint_patch_build[0], 10)

  # Determine if the split disk feature is enabled based on the major, minor and
  # maintenance version numbers.
  split_disk = local.major_minor_version > 92 || (local.major_minor_version == 92 && (var.azure_cces_version == "latest" || local.maint_version >= 2)) ? true : false
}
