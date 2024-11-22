resource "azurerm_virtual_hub" "neu-vhub" {
  name                = "${var.vhub1_location_name}-vhub"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.vhub1_location
  virtual_wan_id      = azurerm_virtual_wan.this.id
  address_prefix      = cidrsubnet(var.vhub1_ip_prefix, 7, 0)
}

resource "azurerm_firewall" "neu-firewall" {
  name                = "${var.vhub1_location_name}-firewall"
  location            = var.vhub1_location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "AZFW_Hub"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.neu-firewall-policy.id

  virtual_hub {
    virtual_hub_id = azurerm_virtual_hub.neu-vhub.id
  }
}

resource "azurerm_firewall_policy" "neu-firewall-policy" {
  name                = "${var.vhub1_location_name}-firewall-policy"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.vhub1_location
}

resource "azurerm_virtual_network" "neu-vnet-01" {
  name                = "${var.vhub1_location_name}-vnet-01"
  address_space       = [cidrsubnet(var.vhub1_ip_prefix, 8, 2)]
  location            = var.vhub1_location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_virtual_hub_connection" "neu-connection-01" {
  name                      = "${var.vhub1_location_name}-vnet-01_${var.vhub1_location_name}-vhub"
  virtual_hub_id            = azurerm_virtual_hub.neu-vhub.id
  remote_virtual_network_id = azurerm_virtual_network.neu-vnet-01.id

  routing {
    static_vnet_route {
      name                = "default-to-nva"
      address_prefixes    = ["0.0.0.0/0"]
      next_hop_ip_address = azurerm_network_interface.neu-nic-01.private_ip_address
    }
    associated_route_table_id = azurerm_virtual_hub_route_table.neu-rt3.id
  }
}

resource "azurerm_subnet" "neu-subnet-01" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.neu-vnet-01.name
  address_prefixes     = [cidrsubnet(var.vhub1_ip_prefix, 9, 4)]
}

resource "azurerm_public_ip" "neu-nat-pip" {
  name                = "${var.vhub1_location_name}-nat-pip"
  location            = var.vhub1_location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "neu-nat" {
  name                = "${var.vhub1_location_name}-nat"
  location            = var.vhub1_location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "neu-nat-pip-association" {
  nat_gateway_id       = azurerm_nat_gateway.neu-nat.id
  public_ip_address_id = azurerm_public_ip.neu-nat-pip.id
}

resource "azurerm_subnet_nat_gateway_association" "neu-nat-association" {
  subnet_id      = azurerm_subnet.neu-subnet-01.id
  nat_gateway_id = azurerm_nat_gateway.neu-nat.id
}

resource "azurerm_network_interface" "neu-nic-01" {
  name                  = "${var.vhub1_location_name}-vm-01-nic"
  location              = var.vhub1_location
  resource_group_name   = azurerm_resource_group.this.name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.neu-subnet-01.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "neu-vm-01" {
  name                            = "${var.vhub1_location_name}-vm-01"
  resource_group_name             = azurerm_resource_group.this.name
  location                        = var.vhub1_location
  size                            = "Standard_B2s"
  admin_username                  = var.username
  admin_password                  = var.password
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.neu-nic-01.id
  ]

  os_disk {
    name                 = "${var.vhub1_location_name}-vm-01-osd"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  custom_data = filebase64("./cloud-init.txt")
  boot_diagnostics {}
}

resource "azurerm_virtual_network" "neu-vnet-02" {
  name                = "${var.vhub1_location_name}-vnet-02"
  address_space       = [cidrsubnet(var.vhub1_ip_prefix, 8, 3)]
  location            = var.vhub1_location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_virtual_hub_connection" "neu-connection-02" {
  name                      = "${var.vhub1_location_name}-vnet-02_${var.vhub1_location_name}-vhub"
  virtual_hub_id            = azurerm_virtual_hub.neu-vhub.id
  remote_virtual_network_id = azurerm_virtual_network.neu-vnet-02.id
  internet_security_enabled = true

  routing {
    associated_route_table_id = azurerm_virtual_hub_route_table.neu-rt1.id
    propagated_route_table {
      route_table_ids = [
        azurerm_virtual_hub.neu-vhub.default_route_table_id,
        azurerm_virtual_hub_route_table.neu-rt3.id
      ]
    }
  }
}

resource "azurerm_subnet" "neu-subnet-02" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.neu-vnet-02.name
  address_prefixes     = [cidrsubnet(var.vhub1_ip_prefix, 9, 6)]
}

resource "azurerm_network_interface" "neu-nic-02" {
  name                = "${var.vhub1_location_name}-vm-02-nic"
  location            = var.vhub1_location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.neu-subnet-02.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "neu-vm-02" {
  name                            = "${var.vhub1_location_name}-vm-02"
  resource_group_name             = azurerm_resource_group.this.name
  location                        = var.vhub1_location
  size                            = "Standard_B2s"
  admin_username                  = var.username
  admin_password                  = var.password
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.neu-nic-02.id,
  ]

  os_disk {
    name                 = "${var.vhub1_location_name}-vm-02-osd"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  boot_diagnostics {}
}

resource "azurerm_virtual_network" "neu-vnet-03" {
  name                = "${var.vhub1_location_name}-vnet-03"
  address_space       = [cidrsubnet(var.vhub1_ip_prefix, 8, 4)]
  location            = var.vhub1_location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_virtual_hub_connection" "neu-connection-03" {
  name                      = "${var.vhub1_location_name}-vnet-03_${var.vhub1_location_name}-vhub"
  virtual_hub_id            = azurerm_virtual_hub.neu-vhub.id
  remote_virtual_network_id = azurerm_virtual_network.neu-vnet-03.id

  routing {
    associated_route_table_id = azurerm_virtual_hub_route_table.neu-rt2.id
  }
}

resource "azurerm_subnet" "neu-subnet-03" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.neu-vnet-03.name
  address_prefixes     = [cidrsubnet(var.vhub1_ip_prefix, 9, 8)]
}

resource "azurerm_network_interface" "neu-nic-03" {
  name                = "${var.vhub1_location_name}-vm-03-nic"
  location            = var.vhub1_location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.neu-subnet-03.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "neu-vm-03" {
  name                            = "${var.vhub1_location_name}-vm-03"
  resource_group_name             = azurerm_resource_group.this.name
  location                        = var.vhub1_location
  size                            = "Standard_B2s"
  admin_username                  = var.username
  admin_password                  = var.password
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.neu-nic-03.id,
  ]

  os_disk {
    name                 = "${var.vhub1_location_name}-vm-03-osd"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  boot_diagnostics {}
}

resource "azurerm_virtual_hub_route_table" "neu-rt1" {
  name           = "DefaultToNVA"
  virtual_hub_id = azurerm_virtual_hub.neu-vhub.id
}

resource "azurerm_virtual_hub_route_table_route" "neu-rt1-default" {
  route_table_id = azurerm_virtual_hub_route_table.neu-rt1.id

  name              = "default-to-nva"
  destinations_type = "CIDR"
  destinations      = ["0.0.0.0/0"]
  next_hop          = azurerm_virtual_hub_connection.neu-connection-01.id
}

resource "azurerm_virtual_hub_route_table_route" "neu-rt1-private" {
  route_table_id = azurerm_virtual_hub_route_table.neu-rt1.id

  name              = "private-to-firewall"
  destinations_type = "CIDR"
  destinations      = ["10.0.0.0/8"]
  next_hop          = azurerm_firewall.neu-firewall.id
}

resource "azurerm_virtual_hub_route_table" "neu-rt2" {
  name           = "PrivateToFirewall"
  virtual_hub_id = azurerm_virtual_hub.neu-vhub.id
}

resource "azurerm_virtual_hub_route_table_route" "neu-rt2-private" {
  route_table_id = azurerm_virtual_hub_route_table.neu-rt2.id

  name              = "private-to-firewall"
  destinations_type = "CIDR"
  destinations      = ["10.0.0.0/8"]
  next_hop          = azurerm_firewall.neu-firewall.id
}

resource "azurerm_virtual_hub_route_table" "neu-rt3" {
  name           = "NVA"
  virtual_hub_id = azurerm_virtual_hub.neu-vhub.id
}

resource "azurerm_virtual_hub_route_table_route" "neu-rt3-private" {
  route_table_id = azurerm_virtual_hub_route_table.neu-rt3.id

  name              = "private-to-firewall"
  destinations_type = "CIDR"
  destinations      = ["10.0.0.0/8"]
  next_hop          = azurerm_firewall.neu-firewall.id
}

resource "azurerm_monitor_diagnostic_setting" "neu-firewall-logs" {
  name                           = "LogsAndMetrics"
  target_resource_id             = azurerm_firewall.neu-firewall.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.law.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "AZFWApplicationRule"
  }

  enabled_log {
    category = "AZFWDnsQuery"
  }

  enabled_log {
    category = "AZFWFatFlow"
  }

  enabled_log {
    category = "AZFWFlowTrace"
  }

  enabled_log {
    category = "AZFWFqdnResolveFailure"
  }

  enabled_log {
    category = "AZFWIdpsSignature"
  }

  enabled_log {
    category = "AZFWNatRule"
  }

  enabled_log {
    category = "AZFWNetworkRule"
  }

  enabled_log {
    category = "AZFWThreatIntel"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "neu-rcg" {
  name               = "DefaultRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.neu-firewall-policy.id
  priority           = 200

  application_rule_collection {
    name     = "Allow-Private-Internet"
    priority = 100
    action   = "Allow"
    rule {
      name = "TCP-80"
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["10.0.0.0/8"]
      destination_fqdns = ["*"]
    }
  }

  network_rule_collection {
    name     = "Allow-Private"
    priority = 200
    action   = "Allow"
    rule {
      name                  = "TCP-UDP-ANY"
      protocols             = ["TCP", "UDP"]
      source_addresses      = ["10.0.0.0/8"]
      destination_addresses = ["10.0.0.0/8"]
      destination_ports     = ["*"]
    }
  }
}