terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# ---------------------------
# Virtual Network + Subnets
# ---------------------------
resource "azurerm_virtual_network" "secure_vnet" {
  name                = "secure-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "function_subnet" {
  name                 = "function-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.secure_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  private_endpoint_network_policies = "Disabled"
 
}

resource "azurerm_subnet" "acr_subnet" {
  name                 = "acr-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.secure_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  private_endpoint_network_policies  = "Disabled"
 
}

# ---------------------------
# Azure Container Registry
# ---------------------------
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false # no public access
}

# Private Endpoint for ACR
resource "azurerm_private_endpoint" "acr_pe" {
  name                = "acr-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.acr_subnet.id

  private_service_connection {
    name                           = "acr-connection"
    private_connection_resource_id = azurerm_container_registry.acr.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }
}

# ---------------------------
# Private DNS Zones
# ---------------------------
resource "azurerm_private_dns_zone" "acr_dns" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "func_dns" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_dns_link" {
  name                  = "acr-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.acr_dns.name
  virtual_network_id    = azurerm_virtual_network.secure_vnet.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "func_dns_link" {
  name                  = "func-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.func_dns.name
  virtual_network_id    = azurerm_virtual_network.secure_vnet.id
}

# ---------------------------
# App Service Plan
# ---------------------------
resource "azurerm_service_plan" "app_plan" {
  name                = "private-app-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "F1"
}

# ---------------------------
# Storage Account (Functions)
# ---------------------------
resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# ---------------------------
# Function Apps
# ---------------------------
locals {
  function_apps = ["inventory", "cart", "payment"]
}

resource "azurerm_linux_function_app" "functions" {
  for_each = toset(local.function_apps)

  name                       = each.key
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.app_plan.id
  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key

  site_config {
    application_stack {
      node_version = "18"
    }
    vnet_route_all_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }
}

# Private Endpoints for Function Apps
resource "azurerm_private_endpoint" "func_pe" {
  for_each            = azurerm_linux_function_app.functions
  name                = "${each.key}-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.function_subnet.id

  private_service_connection {
    name                           = "${each.key}-connection"
    private_connection_resource_id = each.value.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }
}
