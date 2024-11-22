resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.default_location
}

resource "azurerm_virtual_wan" "this" {
  name                = "vwan"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "central-log"
  location            = var.default_location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
