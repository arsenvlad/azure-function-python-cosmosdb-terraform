terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.96.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "resource_group" {
    name = "${var.prefix}-rg"
    location = var.location
}

resource "azurerm_storage_account" "storage_account" {
    name = "${var.prefix}afpctsa1"
    location = var.location
    resource_group_name = azurerm_resource_group.resource_group.name
    account_tier = "Standard"
    account_replication_type = "LRS"
}

# CosmosDB serverless account, database, and container
resource "azurerm_cosmosdb_account" "cosmosdb_account" {
  name = "${var.prefix}-cosmosdb"
  location = var.location
  resource_group_name = azurerm_resource_group.resource_group.name
  offer_type = "Standard"
  kind = "GlobalDocumentDB"

  geo_location {
    location = var.location
    failover_priority = 0
  }

  enable_automatic_failover = false

  consistency_policy {
    consistency_level = "Session"
  }

  capabilities {
    name = "EnableServerless"
  }
}

resource "azurerm_cosmosdb_sql_database" "cosmosdb_database" {
  name = "db1"
  resource_group_name = azurerm_resource_group.resource_group.name
  account_name = azurerm_cosmosdb_account.cosmosdb_account.name
}

resource "azurerm_cosmosdb_sql_container" "cosmosdb_container" {
  name = "container1"
  resource_group_name = azurerm_resource_group.resource_group.name
  account_name = azurerm_cosmosdb_account.cosmosdb_account.name
  database_name = azurerm_cosmosdb_sql_database.cosmosdb_database.name
  partition_key_path = "/id"
}

# Azure Function (Linux and Python 3.9)
resource "azurerm_application_insights" "application_insights" {
    name = "${var.prefix}-appinsights"
    location = var.location
    resource_group_name = azurerm_resource_group.resource_group.name
    application_type = "other"
}

resource "azurerm_app_service_plan" "app_service_plan" {
  name = "${var.prefix}-appsvcplan"
  resource_group_name = azurerm_resource_group.resource_group.name
  location = var.location
  kind = "FunctionApp"
  reserved = true
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "function_app" {
  name = "${var.prefix}-function1"
  location = var.location
  resource_group_name = azurerm_resource_group.resource_group.name
  app_service_plan_id = azurerm_app_service_plan.app_service_plan.id
  storage_account_name = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key
  os_type = "linux"
  version = "~4"
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "python",
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.application_insights.instrumentation_key,
    "CosmosDbEndpoint" = azurerm_cosmosdb_account.cosmosdb_account.endpoint,
    "CosmosDbKey" = azurerm_cosmosdb_account.cosmosdb_account.primary_master_key
  }
  site_config {
      linux_fx_version = "python|3.9"
  }
  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
      app_settings["SCM_DO_BUILD_DURING_DEPLOYMENT"],
    ]
  }
}

# Create ZIP file containing the function code
data "archive_file" "file_function_app" {
  type        = "zip"
  source_dir  = "../function1"
  output_path = "function1.zip"
  excludes = [ "local.settings.json", ".funcignore", ".gitignore", "getting_started.md", "README.md" ]
}

# Use Azure CLI to push a Zip deployment using remote build https://docs.microsoft.com/en-us/azure/azure-functions/functions-deployment-technologies#key-concepts
locals {
    publish_code_command = "az functionapp deployment source config-zip --resource-group ${azurerm_resource_group.resource_group.name} --name ${azurerm_function_app.function_app.name} --src ${data.archive_file.file_function_app.output_path} --build-remote true"
}

resource "null_resource" "function_app_publish" {
  provisioner "local-exec" {
    command = local.publish_code_command
  }
  depends_on = [local.publish_code_command]
  triggers = {
    # Only redeploy if zip file content changed
    input_json = filemd5(data.archive_file.file_function_app.output_path)
    publish_code_command = local.publish_code_command
  }
}