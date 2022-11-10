variable "location" {
  description = "Location to Create all resources"
}

variable "rg-name" {
  description = "The name of the resource group to be created"
}

variable "wkspace-name" {
  description = "The name of the WVD workspace to be created"
  default     = "avd-wkspace"
}

variable "hppooled-name" {
  description = "The name of the WVD pooled hostpool to be created"
  default     = "avd-hp"
}

variable "appgrp-name" {
  description = "The name of the WVD app group to be created"
  default     = "AVD-DAG"
}

/* resource "azurerm_resource_group" "wvdrg" {
  name     = var.rg-name
  location = var.location
}
 */

variable "terraform_script_version" {
  type = string
}

variable "vm_size" {
  description = "Specifies the size of the virtual machine."
}

variable "image_vm_size" {
  description = "Specifies the size of the Image virtual machine."
}

variable "image_publisher" {
  description = "Image Publisher"
}

variable "image_offer" {
  description = "Image Offer"
}

variable "image_sku" {
  description = "Image SKU"
}

variable "image_version" {
  description = "Image Version"
  default     = "latest"
}

variable "admin_username" {
  description = "Local Admin Username"
  default     = ""
}

variable "admin_password" {
  description = "Admin Password"
}
variable "subscription_id" {
  type        = string
  description = "Enter the Subscription ID"
}

variable "domain_controller_rg" {
  type        = string
  description = "Enter the RG name of your domain controller"
}

variable "domain_controller_vnet" {
  type        = string
  description = "Enter the Vnet name of your domain controller:"
}

variable "domain_controller_subnet" {
  type        = string
  description = "Enter the subnet name of your domain controller:"
}

variable "vm_name" {
  description = "Session Host/VM Name:"
}

variable "image_vm_name" {
  description = "Session Host/VM Name:"
}


variable "vm_count" {
  description = "Number of Session Host VMs to create:"
}

variable "vm_shutdown_time" {
  type        = string
  description = "sets the time for scheduled VM shutdown. Ex '1100': "
}

variable "domain" {
  description = "Domain to join"
}

variable "domainuser" {
  description = "Domain Join User Name"
}

variable "domainpassword" {
  description = "Domain User Password"
}

variable "regtoken" {
  description = "Host Pool Registration Token"
  default     = "Host Pool Registration Token"
}

variable "hostpoolname" {
  description = "Host Pool Name to Register Session Hosts"
  default     = "AVD-HP"
}

variable "artifactslocation" {
  description = "Location of WVD Artifacts"
  default     = "https://github.com/acapodil/Azure-Virtual-Desktop/blob/main/Scripts/DSC/Configuration_9-11-2020.zip?raw=true"
}

variable "installTeams" {
  type        = bool
  description = "Installs Teams. Enter true or false boolean value"
}

variable "imageVMCount" {
  type        = bool
  description = "Installs Teams. Enter true or false boolean value"
  default     = false
}

variable "avd_users" {
  description = "AVD users"
  default     = []
}

variable "clientID" {
  type = string
}
variable "clientSecret" {
  type = string
}

variable "tenantID" {
  type = string
}