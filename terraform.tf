variable subscription_id {}
variable environment_prefix {
  default = "clco"
}
variable location {
  default = "westeurope"
}
variable sqladmin_username {
  default = "sqladmin"
}

provider "azuread" {
  version         = "~>0.3"
  subscription_id = "${var.subscription_id}"
}

provider "azurerm" {
  version         = "~>1.27"
  subscription_id = "${var.subscription_id}"
}

provider "random" {
  version         = "~>2.1"
}

resource "azurerm_resource_group" "default" {
  name     = "${var.environment_prefix}"
  location = "${var.location}"
  tags = {
    maintainer   = "ese"
  }
}

resource "random_string" "password_sql" {
  length  = 36
  special = true
}

resource "random_string" "password_sp" {
  length  = 36
  special = false
}

resource "random_string" "namesuffix" {
  length  = 16
  special = false
  # azure converts sql server names silently to lower, that confuses terraform, do not use upper cases
  upper   = false
}

resource "azurerm_sql_server" "spring" {
  # name requires to be azure wide unique 
  name                         = "clco-${random_string.namesuffix.result}"
  resource_group_name          = "${azurerm_resource_group.default.name}"
  location                     = "${azurerm_resource_group.default.location}"
  version                      = "12.0"
  administrator_login          = "${var.sqladmin_username}"
  administrator_login_password = "${random_string.password_sql.result}"
}

output "administrator_login" {
  value = "${azurerm_sql_server.spring.administrator_login}"
}

output "administrator_login_password" {
  value = "${azurerm_sql_server.spring.administrator_login_password}"
}

resource "azurerm_sql_database" "spring" {
  name                = "spring"
  resource_group_name = "${azurerm_resource_group.default.name}"
  location            = "${azurerm_resource_group.default.location}"
  server_name         = "${azurerm_sql_server.spring.name}"
  edition             = "Basic"
}

resource "azuread_application" "address-app" {
  name  = "address-app"
}

resource "azuread_service_principal" "address-app" {
  application_id = "${azuread_application.address-app.application_id}"
  tags = ["ese"]
}

resource "azuread_service_principal_password" "address-app-pass" {
  service_principal_id = "${azuread_service_principal.address-app.id}"
  value                = "${random_string.password_sp.result}"
  end_date             = "${timeadd(timestamp(), "100h")}"
}

resource "azurerm_role_assignment" "address-app-role" {
  scope                = "${azurerm_app_service.spring.id}"
  role_definition_name = "Contributor"
  principal_id         = "${azuread_service_principal.address-app.id}"
}

output "maven-client" {
  value = "${azuread_application.address-app.application_id}"
}

output "maven-key" {
  value = "${random_string.password_sp.result}"
}

resource "azurerm_app_service_plan" "small" {
  name                = "small"
  location            = "${azurerm_resource_group.default.location}"
  resource_group_name = "${azurerm_resource_group.default.name}"
  kind                = "Linux"
  reserved            =  true


  sku {
    tier = "PremiumV2"
    size = "P1v2"
    capacity = 3
  }
}

resource "azurerm_app_service" "spring" {
  name                = "address-app"
  location            = "${azurerm_resource_group.default.location}"
  resource_group_name = "${azurerm_resource_group.default.name}"
  app_service_plan_id = "${azurerm_app_service_plan.small.id}"

  site_config {
    always_on        = true
    linux_fx_version = "JAVA|8-jre8"
  }

  app_settings = {
    SpringBoot_DBConnection = "jdbc:sqlserver://${azurerm_sql_server.spring.name}.database.windows.net:1433;database=${azurerm_sql_database.spring.name};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;"
    SpringBoot_DBPassword   = "${azurerm_sql_server.spring.administrator_login_password}"
    SpringBoot_DBUser       = "${var.sqladmin_username}@${azurerm_sql_server.spring.name}"
  }

  connection_string {
    name  = "Database"
    type  = "SQLServer"
    value = "jdbc:sqlserver://${azurerm_sql_server.spring.name}.database.windows.net:1433;database=${azurerm_sql_database.spring.name};user=${var.sqladmin_username}@${azurerm_sql_server.spring.name};password=${random_string.password_sql.result};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;"
  }
}

output "webapp-resource-group" {
  value = "${azurerm_app_service.spring.resource_group_name}"
}

output "webapp-region" {
  value = "${azurerm_app_service.spring.location}"
}

output "webapp-name" {
  value = "${azurerm_app_service.spring.name}"
}

locals {
  outbound_ip = "${split(",", azurerm_app_service.spring.possible_outbound_ip_addresses)}"
}

resource "azurerm_sql_firewall_rule" "address-app-rule" {
  count               = "${length(local.outbound_ip)}"
  name                = "allow outbound ip ${local.outbound_ip[count.index]}"
  resource_group_name = "${azurerm_resource_group.default.name}"
  server_name         = "${azurerm_sql_server.spring.name}"
  start_ip_address    = "${local.outbound_ip[count.index]}"
  end_ip_address      = "${local.outbound_ip[count.index]}"
}

resource "azurerm_monitor_autoscale_setting" "address-scale" {
  name                = "small-Autoscale-312"
  resource_group_name = "${azurerm_resource_group.default.name}"
  location            = "${azurerm_resource_group.default.location}"
  target_resource_id  = "${azurerm_app_service_plan.small.id}"

  profile {
    name = "small-Autoscale-312"

    capacity {
      default = "2"
      minimum = "2"
      maximum = "${azurerm_app_service_plan.small.maximum_number_of_workers}"
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = "${azurerm_app_service_plan.small.id}"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = "${azurerm_app_service_plan.small.id}"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}