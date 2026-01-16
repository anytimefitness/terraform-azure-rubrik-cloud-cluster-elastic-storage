# Terraform Module - Azure Cloud Cluster Elastic Storage Deployment
This module deploys a new Rubrik Cloud Cluster Elastic Storage (CCES) in Azure.

> **Note:** This is a fork of the upstream repository. Releases are published through GitHub using reference tags.

## Usage
```hcl
module "rubrik_azure_cloud_cluster_elastic_storage" {
  source  = "github.com/<owner>/terraform-azure-rubrik-cloud-cluster-elastic-storage?ref=v1.1.0"

  admin_email           = "build@rubrik.com"
  admin_password        = "RubrikGoForward"
  azure_cces_plan_name  = "rubrik-cdm-90"
  azure_cces_sku        = "rubrik-cdm-90"
  azure_location        = "West US2"
  azure_resource_group  = "Rubrik-CCES"
  azure_sa_name         = "rubrikcces"
  azure_subnet_name     = "private-subnet"
  azure_vnet_name       = "private-vnet"
  azure_vnet_rg_name    = "Company_VNets"
  cluster_name          = "rubrik-cloud-cluster"
  dns_name_servers      = ["8.8.8.8", "8.8.4.4"]
  dns_search_domain     = ["rubrikdemo.com"]
  number_of_nodes       = 3
  ntp_server1_name      = "0.north-america.pool.ntp.org"
  ntp_server2_name      = "1.north-america.pool.ntp.org"
}
```

## Upgrading
Before upgrading the module, be sure to check the GitHub releases page to understand the changes in the new version and any
upgrade instructions for the version you are upgrading to. 

To upgrade the module to a new version, use the following steps:
1. Update the `ref` parameter in the `source` field of the `module` block to the version tag you want to upgrade to, e.g. `ref=v1.0.3`.
2. Run `terraform init --upgrade` to update the modules in your configuration.
3. Run `terraform plan` and check the output carefully to ensure that there are no unexpected changes caused by the
   upgrade.
4. Run `terraform apply` if there are expected changes that you want to apply.

Note, as variables in the module are deprecated, you may see warnings in the output of `terraform plan`. These warnings
can be ignored, but it's recommended that you follow the instructions in the deprecation message. Eventually deprecated
variables will be removed.

### v1.0.0 to v1.0.1
In version `v1.0.1` the `azure_subscription_id` input variable has been deprecated. If you are using the input variable,
you will see a warning message similar to this:
```text
The 'azure_subscription_id' variable is deprecated and should not be used as it will be removed in a future release. Configure the subscription ID in the azurerm provider configuration instead.
```
Remove the variable from your module block and instead pass it to the Azure RM provider configuration block in the root
module. Similar to this:
```hcl
provider "azurerm" {
  subscription_id = "<subscription-id>"
}
```
Where `<subscription-id>` is your Azure subscription ID.

### v0.2.0 to v1.0.0
In version `v1.0.0` the provider configuration blocks has been removed from the module to support the `for_each`
meta-argument. Instead, the configuration blocks needs to be specified in the root module of the Terraform
configuration. If your root module doesn't already contain a provider configuration block for the Azure RM provider,
you can use this provider configuration block: 
```hcl
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

  subscription_id = "<subscription-id>"
}
```
Where `<subscription-id>` is your Azure subscription ID.

## Authenticating with Azure
You can authenticate Terraform with Azure by either using the Azure CLI or by using environment variables.

### Authenticating with Azure CLI
[Terraform Module for AzureRM CLI Authentication](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli)
provides a complete guide on how to authenticate Terraform with Azure. The following commands can be used from a command
line interface with the [Microsoft Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) to manually
run Terraform:
```shell
az login --tenant <tenant-id>
```
Where `<tenant-id>` is the ID of the tenant to log in to. If you only have one tenant you can remove the `--tenant`
option.

Next before running this module, the subscription must be selected. Do this by running the command:
```shell
az account set --subscription <subscription-id>
```
Where `<subscription-id>` is the ID of the subscription where CCES will be deployed.

### Authenticating with Environment Variables
For environments that require a non-interactive authentication method such as Terraform Cloud, the Azure CLI can be
authenticated using environment variables. The following environment variables must be set:
* `ARM_CLIENT_ID`
* `ARM_CLIENT_SECRET`
* `ARM_TENANT_ID`
Additionally, you can set `ARM_SUBSCRIPTION_ID`. But if you specify the subscription ID in the root module of your
configuration, this is not mandatory.

The environment variables can be set as follows in your terminal:
```shell
export ARM_CLIENT_ID="<client-id>"
export ARM_CLIENT_SECRET="<client-secret>"
export ARM_TENANT_ID="<tenant-id>"
```
Where `<client-id>` is the application ID of your application in Entra ID, `<client-secret>` is the secret of your
application in Entra ID and `<tenant-id>` is the ID of your tenant in Azure. Alternatively, they can be added to the
workspace variables in Terraform Cloud.

If you unsure how to get these, you can use the Azure CLI to create a service principal and get the values. See the
[Azure CLI documentation](https://learn.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli) for
more information.

### Accept the Azure Marketplace Agreement for CCES
In order to deploy Cloud Cluster ES from the Azure marketplace two things must happen. First, the marketplace agreement
for the specific plan must be accepted in the subscription where Cloud Cluster ES will be deployed. Second, valid values
for the `azure_cces_plan_name` and `azure_cces_sku` input variables must be collected. 

One method for accepting the Marketplace Agreement is to use the Azure CLI. To do this the SKU of the Azure Marketplace
Plan for CCES to use must first be identified. To do this run the command:
```shell
az vm image list-skus --location <location> -p rubrik-inc -f rubrik-data-protection --output table`
```
Where `<location>` is the Azure Location code for the region where CCES will be deployed. E.g:
```shell
az vm image list-skus --location westus2 -p rubrik-inc -f rubrik-data-protection --output table
```
Depending on the current set of SKUs available, the result should look something similar to:
```
Location    Name
----------  --------------
westus2     rubrik-cdm-60
westus2     rubrik-cdm-70
westus2     rubrik-cdm-80
westus2     rubrik-cdm-81
westus2     rubrik-cdm-90
```

Tke SKUs in the output will represent the major and minor version numbers of the various Rubrik CCES releases. For
example `rubrik-cdm-90` represents Rubrik CDM `v9.0.x`. The specific maintenance release will be selected later on.
Select the SKU name for the version of CCES that you plan to use.

Next the plan name for the SKU that has been selected must be obtained. Generally with CCES the plan name and the SKU
name are the same, however, it is best to check in case they do differ. To do this run the command:
```shell
az vm image show --location <location> --urn rubrik-inc:rubrik-data-protection:<SKU>:latest --query plan.name --output tsv
```
Where `<location>` is the Azure Location code for the region where CCES will be deployed and `<SKU>` is the SKU that was
selected in the previous step. E.g:
```shell
az vm image show --location westus2 --urn rubrik-inc:rubrik-data-protection:rubrik-cdm-90:latest --query plan.name --output tsv    
```

Next the Azure Marketplace Agreement must be accepted. To do this run the command:
```shell
az vm image terms accept --offer rubrik-data-protection --publisher rubrik-inc --plan <plan-name> --output jsonc
```
Where `<plan-name>` is the name of the plan that was collected in the previous step. E.g:
```shell
az vm image terms accept --offer rubrik-data-protection --publisher rubrik-inc --plan rubrik-cdm-90 --output jsonc  
```
Depending on the plan accepted, the result should look something similar to:
```
{
  "accepted": true,
  "id": "/subscriptions/<Subscription_ID>/providers/Microsoft.MarketplaceOrdering/offerTypes/Microsoft.MarketplaceOrdering/offertypes/publishers/rubrik-inc/offers/rubrik-data-protection/plans/rubrik-cdm-90/agreements/current",
  "licenseTextLink": "https://storelegalterms.blob.core.windows.net/legalterms/3E5ED_legalterms_RUBRIK%253a2DINC%253a24RUBRIK%253a2DDATA%253a2DPROTECTION%253a24RUBRIK%253a2DCDM%253a2D90%253a24JRAHGUAQ44GVF2TFRYQ5727EY5ZA3HLQ3KU2L76ISIHHQQY2ZJYDCGQTOHXDJ7LU7UO4PPM6UM6DMUQXIIVE763XZJZZNTLHNRCZXBA.txt",
  "marketplaceTermsLink": "https://mpcprodsa.blob.core.windows.net/marketplaceterms/3EDEF_marketplaceterms_VIRTUALMACHINE%253a24AAK2OAIZEAWW5H4MSP5KSTVB6NDKKRTUBAU23BRFTWN4YC2MQLJUB5ZEYUOUJBVF3YK34CIVPZL2HWYASPGDUY5O2FWEGRBYOXWZE5Y.txt",
  "name": "rubrik-cdm-90",
  "plan": "rubrik-cdm-90",
  "privacyPolicyLink": "https://www.rubrik.com/legal/privacy-policy",
  "product": "rubrik-data-protection",
  "publisher": "rubrik-inc",
  "retrieveDatetime": "2023-09-04T05:14:55.6081829Z",
  "signature": "<Unique_Signature>",
  "systemData": {
    "createdAt": "2023-09-04T05:14:57.794366+00:00",
    "createdBy": "<Subscription_ID>",
    "createdByType": "ManagedIdentity",
    "lastModifiedAt": "2023-09-04T05:14:57.794366+00:00",
    "lastModifiedBy": "<Subscription_ID>",
    "lastModifiedByType": "ManagedIdentity"
  },
  "type": "Microsoft.MarketplaceOrdering/offertypes"
}
```
Verify that the `accepted` field is set to `true`.

The values for the `azure_cces_sku` and the `azure_cces_plan_name` input variables are the SKU name and plan name that
were collected in the previous steps.

### Select the version of CCES to deploy (optional)
By default, this module will deploy the latest version of CCES that is available in the SKU that the `azure_cces_sku`
input variable is set to. If a specific version of CCES is desired for a given SKU, run the following command to get the
available version numbers:
```shell
az vm image list --location <location> --publisher rubrik-inc --offer rubrik-data-protection --sku <SKU> --all --query sku --query "[].version" --output tsv
```
Where `<location>` is the Azure Location code for the region where CCES will be deployed and `<SKU>` is the SKU that was
selected in the previous step.

With CDM `v8.0` and earlier the versions numbers represent the `major.minor.maintenance` number of the release. For
example `8.0.3` represents `CDM 8.0.3-p9-22986`. There is an assumption that every maintenance release is the latest
patch release as well. As patches are released to a maintenance release, the older patch release is removed. 

With CDM `v8.1` and later the version numbers represent the `minor.maintenance.build` number of the release. The SKU
number represents the `major.minor` number of the release. For example the plan `rubrik-cdm-81` with a version number of
`3.1.24838` represents `8.1.3-p1-24838`. This notation allows the user to understand what patch release is represented
in the marketplace. The build numbers correspond to the various patch releases. 

Set the input variable `azure_cces_version` to the version number from the list that is desired. Setting the
`azure_cces_version` input variable to `latest` will deploy the latest version of CCES from the list.

### Subnet Network Storage Endpoint
This module will attempt to enable the Storage Endpoint in the subnet where CCES is deployed by default. A Storage
Endpoint is required by CCES. If a VNet Storage Endpoint or private Storage Endpoint will be used, the default behaviour
of the module can be disabled by setting the `azure_enable_subnet_storage_endpoint` to `false`.

## Additional Documentation
* [Microsoft Azure CLI Installation](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
* [Microsoft Azure CLI Authentication](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli)
* [Terraform Module for AzureRM CLI Authentication](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2.0 |
| <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) | >=2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >=4.14.0 |
| <a name="requirement_polaris"></a> [polaris](#requirement\_polaris) | >=1.1.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azapi"></a> [azapi](#provider\_azapi) | >=2.0.0 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >=4.14.0 |
| <a name="provider_polaris"></a> [polaris](#provider\_polaris) | >=1.1.3 |
| <a name="provider_time"></a> [time](#provider\_time) | n/a |
| <a name="provider_tls"></a> [tls](#provider\_tls) | n/a |

## Resources

| Name | Type |
|------|------|
| [azapi_resource.cc_container](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azapi_update_resource.cces_subnet_storage_endpoint](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/update_resource) | resource |
| [azurerm_key_vault.cc_key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_key_vault_secret.cc_private_ssh_key](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_linux_virtual_machine.cces_node](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine) | resource |
| [azurerm_managed_disk.cces_cache_disk](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/managed_disk) | resource |
| [azurerm_managed_disk.cces_data_disk](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/managed_disk) | resource |
| [azurerm_managed_disk.cces_metadata_disk](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/managed_disk) | resource |
| [azurerm_management_lock.cces_cache_disk](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) | resource |
| [azurerm_management_lock.cces_data_disk](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) | resource |
| [azurerm_management_lock.cces_metadata_disk](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) | resource |
| [azurerm_management_lock.cces_nic](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) | resource |
| [azurerm_management_lock.cces_node](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) | resource |
| [azurerm_network_interface.cces_nic](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) | resource |
| [azurerm_resource_group.cc_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_ssh_public_key.cc_public_ssh_key](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/ssh_public_key) | resource |
| [azurerm_storage_account.cc_storage_account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_virtual_machine_data_disk_attachment.cces_cache_disk](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_data_disk_attachment) | resource |
| [azurerm_virtual_machine_data_disk_attachment.cces_data_disk](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_data_disk_attachment) | resource |
| [azurerm_virtual_machine_data_disk_attachment.cces_metadata_disk](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_data_disk_attachment) | resource |
| [polaris_cdm_bootstrap_cces_azure.bootstrap_cces_azure](https://registry.terraform.io/providers/rubrikinc/polaris/latest/docs/resources/cdm_bootstrap_cces_azure) | resource |
| [polaris_cdm_registration.cces_azure_registration](https://registry.terraform.io/providers/rubrikinc/polaris/latest/docs/resources/cdm_registration) | resource |
| [time_sleep.wait_for_nodes_to_boot](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [tls_private_key.cc-key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_subnet.cces_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_email"></a> [admin\_email](#input\_admin\_email) | The Rubrik Cloud Cluster sends messages for the admin account to this email address. | `string` | n/a | yes |
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | Password for the Rubrik Cloud Cluster admin account. | `string` | `"ChangeMe"` | no |
| <a name="input_azure_cces_plan_name"></a> [azure\_cces\_plan\_name](#input\_azure\_cces\_plan\_name) | The Azure Marketplace Plan Name/ID of the CCES image to deploy. See the README.MD file of this module for information on finding the plan name. | `any` | n/a | yes |
| <a name="input_azure_cces_sku"></a> [azure\_cces\_sku](#input\_azure\_cces\_sku) | The SKU for the Azure Marketplace Image of CCES to deploy. See the README.MD file of this module for information on finding the SKU. | `string` | n/a | yes |
| <a name="input_azure_cces_version"></a> [azure\_cces\_version](#input\_azure\_cces\_version) | The version of CCES to deploy. Use 'latest' to deploy the latest available version. Note: This only applies to the version within a SKU (major/minor version). | `string` | `"latest"` | no |
| <a name="input_azure_cces_vm_size"></a> [azure\_cces\_vm\_size](#input\_azure\_cces\_vm\_size) | The Azure VM Machine Type to use for the Cloud Cluster nodes. | `string` | `"Standard_D16s_v5"` | no |
| <a name="input_azure_enable_subnet_storage_endpoint"></a> [azure\_enable\_subnet\_storage\_endpoint](#input\_azure\_enable\_subnet\_storage\_endpoint) | Whether to enable the Storage service endpoint on the VPC subnet. Defaults to `true`. | `bool` | `true` | no |
| <a name="input_azure_key_vault_name"></a> [azure\_key\_vault\_name](#input\_azure\_key\_vault\_name) | The name of the Azure Key Vault to create, into which the CCES private ssh key will be stored. | `string` | `""` | no |
| <a name="input_azure_location"></a> [azure\_location](#input\_azure\_location) | The region to deploy Rubrik Cloud Cluster resources. | `any` | n/a | yes |
| <a name="input_azure_resource_group"></a> [azure\_resource\_group](#input\_azure\_resource\_group) | The Azure Resource Group into which deploy Rubrik Cloud Cluster resources. | `string` | `"RubrikCloudCluster"` | no |
| <a name="input_azure_resource_lock"></a> [azure\_resource\_lock](#input\_azure\_resource\_lock) | Enable the Azure Resource Lock on critical components that are created by this module. | `bool` | `true` | no |
| <a name="input_azure_sa_name"></a> [azure\_sa\_name](#input\_azure\_sa\_name) | The name of the Azure Storage Account to create for Rubrik Cloud Cluster resources. | `string` | n/a | yes |
| <a name="input_azure_sa_replication_type"></a> [azure\_sa\_replication\_type](#input\_azure\_sa\_replication\_type) | The type of replication to use with the the Azure Storage Account for Rubrik Cloud Cluster. | `string` | `"LRS"` | no |
| <a name="input_azure_subnet_name"></a> [azure\_subnet\_name](#input\_azure\_subnet\_name) | Name of the Azure subnet to deploy Rubrik Cloud Cluster into. This subnet must be in the VNet that is defined in the 'azure\_vnet\_name' variable. | `string` | n/a | yes |
| <a name="input_azure_subscription_id"></a> [azure\_subscription\_id](#input\_azure\_subscription\_id) | Subscription ID of the Azure account to deploy Rubrik Cloud Cluster resources. Deprecated: This variable is no longer required as the subscription ID is now determined by the provider configuration. | `string` | `null` | no |
| <a name="input_azure_tags"></a> [azure\_tags](#input\_azure\_tags) | Tags to add to the Azure resources that this Terraform script creates, including the Rubrik cluster nodes. | `map(string)` | `{}` | no |
| <a name="input_azure_vnet_name"></a> [azure\_vnet\_name](#input\_azure\_vnet\_name) | Name of the Azure Virtual Network (VNet) to deploy Rubrik Cloud Cluster ES into. | `string` | n/a | yes |
| <a name="input_azure_vnet_rg_name"></a> [azure\_vnet\_rg\_name](#input\_azure\_vnet\_rg\_name) | Name of the Resource Group of the Azure VNet that is defined in the 'azure\_vnet\_name' variable. | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Unique name to assign to the Rubrik Cloud Cluster. This will also be used as part of the Storage Account name. For example, rubrik-cloud-cluster-1, rubrik-cloud-cluster-2 etc. | `string` | `"rubrik-cloud-cluster"` | no |
| <a name="input_dns_name_servers"></a> [dns\_name\_servers](#input\_dns\_name\_servers) | List of the IPv4 addresses of the DNS servers. | `list(any)` | <pre>[<br/>  "169.254.169.253"<br/>]</pre> | no |
| <a name="input_dns_search_domain"></a> [dns\_search\_domain](#input\_dns\_search\_domain) | List of search domains that the DNS Service will use to resolve host names that are not fully qualified. | `list(any)` | `[]` | no |
| <a name="input_enableImmutability"></a> [enableImmutability](#input\_enableImmutability) | Enables object lock and versioning on the Storage Account and Container. Sets the object lock flag during bootstrap. Not supported on CDM v8.0.1 and earlier. | `bool` | `true` | no |
| <a name="input_ntp_server1_key"></a> [ntp\_server1\_key](#input\_ntp\_server1\_key) | Symmetric key material for NTP server #1. | `string` | `""` | no |
| <a name="input_ntp_server1_key_id"></a> [ntp\_server1\_key\_id](#input\_ntp\_server1\_key\_id) | The ID number of the symmetric key used with NTP server #1. (Typically this is 0) | `number` | `0` | no |
| <a name="input_ntp_server1_key_type"></a> [ntp\_server1\_key\_type](#input\_ntp\_server1\_key\_type) | Symmetric key type for NTP server #1. | `string` | `""` | no |
| <a name="input_ntp_server1_name"></a> [ntp\_server1\_name](#input\_ntp\_server1\_name) | The FQDN or IPv4 addresses of network time protocol (NTP) server #1. | `string` | `"8.8.8.8"` | no |
| <a name="input_ntp_server2_key"></a> [ntp\_server2\_key](#input\_ntp\_server2\_key) | Symmetric key material for NTP server #2. | `string` | `""` | no |
| <a name="input_ntp_server2_key_id"></a> [ntp\_server2\_key\_id](#input\_ntp\_server2\_key\_id) | The ID number of the symmetric key used with NTP server #2. (Typically this is 0) | `number` | `0` | no |
| <a name="input_ntp_server2_key_type"></a> [ntp\_server2\_key\_type](#input\_ntp\_server2\_key\_type) | Symmetric key type for NTP server #2. | `string` | `""` | no |
| <a name="input_ntp_server2_name"></a> [ntp\_server2\_name](#input\_ntp\_server2\_name) | The FQDN or IPv4 addresses of network time protocol (NTP) server #2. | `string` | `"8.8.4.4"` | no |
| <a name="input_number_of_nodes"></a> [number\_of\_nodes](#input\_number\_of\_nodes) | The total number of nodes in Rubrik Cloud Cluster. | `number` | `3` | no |
| <a name="input_register_cluster_with_rsc"></a> [register\_cluster\_with\_rsc](#input\_register\_cluster\_with\_rsc) | Register the Rubrik Cloud Cluster with Rubrik Security Cloud. | `bool` | `false` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | The number of seconds to wait to establish a connection the Rubrik cluster before returning a timeout error. | `string` | `"4m"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_key_vault_get_ssh_key_command"></a> [key\_vault\_get\_ssh\_key\_command](#output\_key\_vault\_get\_ssh\_key\_command) | n/a |
| <a name="output_rubrik_cloud_cluster_ip_addresses"></a> [rubrik\_cloud\_cluster\_ip\_addresses](#output\_rubrik\_cloud\_cluster\_ip\_addresses) | n/a |
<!-- END_TF_DOCS -->

## How You Can Help

We glady welcome contributions from the community. From updating the documentation to adding more functionality, all ideas are welcome. Thank you in advance for all of your issues, pull requests, and comments!

- [Contributing Guide](CONTRIBUTING.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)

## License

- [MIT License](LICENSE)

## About Rubrik Build

We encourage all contributors to become members. We aim to grow an active, healthy community of contributors, reviewers, and code owners. Learn more in our [Welcome to the Rubrik Build Community](https://github.com/rubrikinc/welcome-to-rubrik-build) page.

We'd love to hear from you! Email us: build@rubrik.com
