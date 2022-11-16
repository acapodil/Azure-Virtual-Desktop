#terraform block
# Terraform
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
  }
}

#provider block
provider "azurerm" {
  features {}
}

#Resource Group
resource "azurerm_resource_group" "avd_rg" {
  name     = var.rg-name
  location = var.location

}

#Workspace
resource "azurerm_virtual_desktop_workspace" "workspace" {
  name                = var.wkspace-name
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name

  friendly_name = var.wkspace-name
  description   = "Workspace deployed using Terraform"
}

#Hostpool
resource "azurerm_virtual_desktop_host_pool" "avdhppooled" {
  name                = var.hppooled-name
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name

  type                     = "Pooled"
  load_balancer_type       = "BreadthFirst"
  custom_rdp_properties    = "audiocapturemode:i:1;camerastoredirect:s:*;use multimon:i:0"
  start_vm_on_connect      = false
  maximum_sessions_allowed = 20
}

//Generates host pool token
resource "azurerm_virtual_desktop_host_pool_registration_info" "reg_token" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.avdhppooled.id
  expiration_date = timeadd(timestamp(), "2h")
}

#App Group (desktop)
resource "azurerm_virtual_desktop_application_group" "desktopapp" {
  name                = var.appgrp-name
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name

  type          = "Desktop"
  host_pool_id  = azurerm_virtual_desktop_host_pool.avdhppooled.id
  friendly_name = var.appgrp-name
  description   = "Dekstop Application Group"
}


#Associate desktop group to workspace
resource "azurerm_virtual_desktop_workspace_application_group_association" "workspaceremoteapp" {
  workspace_id         = azurerm_virtual_desktop_workspace.workspace.id
  application_group_id = azurerm_virtual_desktop_application_group.desktopapp.id
}

#deploy log analytics workspace for insights
resource "azurerm_log_analytics_workspace" "example" {
  name                = "avdLog"
  location            = var.location
  resource_group_name = azurerm_resource_group.avd_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

#random string for storage account creation
resource "random_string" "random" {
  length  = 4
  upper   = false
  special = false
}

#Storage Account
resource "azurerm_storage_account" "storage" {
  name                     = "${random_string.random.id}users"
  resource_group_name      = azurerm_resource_group.avd_rg.name
  location                 = var.location
  account_tier             = "Premium"
  account_replication_type = "LRS"
  account_kind             = "FileStorage"
}

#create SMB Share
resource "azurerm_storage_share" "FSShare" {
  name                 = "userprofiles"
  quota                = "150"
  storage_account_name = azurerm_storage_account.storage.name
  depends_on           = [azurerm_storage_account.storage]
}


#build Session Host NIC
resource "azurerm_network_interface" "nic" {
  name                = "${var.vm_name}-${count.index}"
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name
  count               = var.vm_count

  ip_configuration {
    name                          = "webipconfig${count.index}"
    subnet_id                     = "/subscriptions/${var.subscription_id}/resourceGroups/${var.domain_controller_rg}/providers/Microsoft.Network/virtualNetworks/${var.domain_controller_vnet}/subnets/${var.domain_controller_subnet}"
    private_ip_address_allocation = "Dynamic"
  }
}

#Build Session Host VMs
resource "azurerm_virtual_machine" "vm" {
  name                          = "${var.vm_name}-${count.index}"
  location                      = azurerm_resource_group.avd_rg.location
  resource_group_name           = azurerm_resource_group.avd_rg.name
  vm_size                       = var.vm_size
  network_interface_ids         = ["${element(azurerm_network_interface.nic.*.id, count.index)}"]
  count                         = var.vm_count
  delete_os_disk_on_termination = true
  depends_on                    = [azurerm_virtual_desktop_host_pool.avdhppooled]


  storage_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  storage_os_disk {
    name          = "${var.vm_name}-${count.index}"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = "${var.vm_name}${count.index}"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }
}

#auto shutdown Sessionhosts 
resource "azurerm_dev_test_global_vm_shutdown_schedule" "auto_shutdown_session_hosts" {
  location              = azurerm_resource_group.avd_rg.location
  virtual_machine_id    = element(azurerm_virtual_machine.vm.*.id, count.index)
  enabled               = true
  daily_recurrence_time = var.vm_shutdown_time
  timezone              = "Eastern Standard Time"
  count                 = var.vm_count

  notification_settings {
    enabled = false
  }
}

#Domain-join Session Hosts
resource "azurerm_virtual_machine_extension" "domainjoinext" {
  name                 = "join-domain"
  virtual_machine_id   = element(azurerm_virtual_machine.vm.*.id, count.index)
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.0"
  depends_on           = [azurerm_virtual_machine.vm]
  count                = var.vm_count

  settings = <<SETTINGS
    {
        "Name": "${var.domain}",
        "User": "${var.domainuser}",
        "Restart": "true",
        "Options": "3"
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
        "Password": "${var.domainpassword}"
    }
PROTECTED_SETTINGS
}

#Run DSC on Session Hosts
resource "azurerm_virtual_machine_extension" "registersessionhost" {
  name                       = "registersessionhost"
  virtual_machine_id         = element(azurerm_virtual_machine.vm.*.id, count.index)
  publisher                  = "Microsoft.Powershell"
  depends_on                 = [azurerm_virtual_machine_extension.domainjoinext]
  count                      = var.vm_count
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true
  settings                   = <<SETTINGS
    {
        "ModulesUrl": "${var.artifactslocation}",
        "ConfigurationFunction" : "Configuration.ps1\\AddSessionHost",
        "Properties": {
            "hostPoolName": "${var.hostpoolname}",
            "registrationInfoToken": "${azurerm_virtual_desktop_host_pool_registration_info.reg_token[0].token}"
        }
    }
SETTINGS
}

#run custom script extension for FSLOGIX
resource "azurerm_virtual_machine_extension" "custom_script" {
  name                 = "${var.vm_name}-${format("%02d", count.index)}-customscript"
  count                = var.vm_count
  virtual_machine_id   = element(azurerm_virtual_machine.vm.*.id, count.index)
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  depends_on           = [azurerm_virtual_machine_extension.registersessionhost]

  settings = jsonencode({

    "fileUris" : ["https://raw.githubusercontent.com/acapodil/Azure-Virtual-Desktop/main/Scripts/customScriptTerraform.ps1"]
    "commandToExecute" : "powershell -ExecutionPolicy Unrestricted -File customScriptTerraform.ps1 ${azurerm_storage_account.storage.name}"
  })

  tags = {
    environment = "Production"
  }
}


#Deploy Image VM#############################

#build Session Host NIC
resource "azurerm_network_interface" "imagevm_nic" {
  name                = "${var.image_vm_name}-NIC"
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name
  depends_on = [
    azurerm_virtual_machine_extension.custom_script
  ]
  ip_configuration {
    name                          = "imgvmipconfig"
    subnet_id                     = "/subscriptions/${var.subscription_id}/resourceGroups/${var.domain_controller_rg}/providers/Microsoft.Network/virtualNetworks/${var.domain_controller_vnet}/subnets/${var.domain_controller_subnet}"
    private_ip_address_allocation = "Dynamic"
  }
}

# #Build Image VM
resource "azurerm_virtual_machine" "image_vm" {
  name                          = var.image_vm_name
  location                      = azurerm_resource_group.avd_rg.location
  resource_group_name           = azurerm_resource_group.avd_rg.name
  vm_size                       = var.image_vm_size
  network_interface_ids         = [azurerm_network_interface.imagevm_nic.id]
  delete_os_disk_on_termination = true
  depends_on                    = [azurerm_network_interface.imagevm_nic]


  storage_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  storage_os_disk {
    name          = "${var.image_vm_name}-OSD"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = var.image_vm_name
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }
}

#auto shutdown imageVM
resource "azurerm_dev_test_global_vm_shutdown_schedule" "auto_shutdown_imageVM" {
  location              = azurerm_resource_group.avd_rg.location
  virtual_machine_id    = azurerm_virtual_machine.image_vm.id
  enabled               = true
  daily_recurrence_time = var.vm_shutdown_time
  timezone              = "Eastern Standard Time"

  notification_settings {
    enabled = false
  }
}

# #Domain-join IMG VM
resource "azurerm_virtual_machine_extension" "imageVM_domainjoin" {
  name                 = "join-domain"
  virtual_machine_id   = azurerm_virtual_machine.image_vm.id
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.0"
  depends_on           = [azurerm_virtual_machine.image_vm]

  settings = <<SETTINGS
    {
        "Name": "${var.domain}",
        "User": "${var.domainuser}",
        "Restart": "true",
        "Options": "3"
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
        "Password": "${var.domainpassword}"
    }
PROTECTED_SETTINGS
}

resource "azurerm_virtual_machine_extension" "image_vm_custom_script" {
  name                 = "${var.image_vm_name}-customscript"
  virtual_machine_id   = azurerm_virtual_machine.image_vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  depends_on           = [azurerm_virtual_machine_extension.imageVM_domainjoin]

  settings = jsonencode({

    "fileUris" : ["https://raw.githubusercontent.com/acapodil/Azure-Virtual-Desktop/main/Scripts/customScriptTerraform.ps1"]
    "commandToExecute" : "powershell -ExecutionPolicy Unrestricted -File customScriptTerraform.ps1 ${azurerm_storage_account.storage.name}"
  })

  tags = {
    environment = "Production"
  }
}



