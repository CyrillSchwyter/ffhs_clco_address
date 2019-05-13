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

resource "random_string" "password" {
  length  = 36
  special = true
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
  administrator_login_password = "${random_string.password.result}"
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

resource "azurerm_app_service_plan" "small" {
  name                = "small"
  location            = "${azurerm_resource_group.default.location}"
  resource_group_name = "${azurerm_resource_group.default.name}"
  kind                = "Linux"

  sku {
    tier = "Basic"
    size = "B1"
  }
}

resource "azurerm_app_service" "spring" {
  name                = "address-app"
  location            = "${azurerm_resource_group.default.location}"
  resource_group_name = "${azurerm_resource_group.default.name}"
  app_service_plan_id = "${azurerm_app_service_plan.small.id}"

  site_config {
    always_on              = true
    java_version           = "1.8"
    java_container         = "Tomcat"
    java_container_version = "8.5"
  }

  app_settings = {
    SpringBoot_DBConnection = "jdbc:sqlserver://${azurerm_sql_server.spring.name}.database.windows.net:1433;database=${azurerm_sql_database.spring.name};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;"
    SpringBoot_DBPassword   = "${azurerm_sql_server.spring.administrator_login_password}"
    SpringBoot_DBUser       = "${var.sqladmin_username}@${azurerm_sql_server.spring.name}"
  }

  connection_string {
    name  = "Database"
    type  = "SQLServer"
    value = "jdbc:sqlserver://${azurerm_sql_server.spring.name}.database.windows.net:1433;database=${azurerm_sql_database.spring.name};user=${var.sqladmin_username}@${azurerm_sql_server.spring.name};password=${random_string.password.result};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;"
  }
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