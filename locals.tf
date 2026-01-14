#############################
# Dynamic Variable Creation #
#############################

locals {
  enableImmutability = var.enableImmutability == true ? 1 : 0
  cluster_node_names = formatlist("${var.cluster_name}-%02s", range(1, var.number_of_nodes + 1))
  cluster_node_ips   = [for i in azurerm_linux_virtual_machine.cces_node : i.private_ip_address]
}
