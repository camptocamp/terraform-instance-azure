data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "azurerm_public_ip" "this" {
  count = var.instance_count

  name                = format("%s%d", var.module_name, count.index)
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  tags                = var.tags
}

resource "azurerm_network_interface" "this" {
  count = var.instance_count

  name                      = format("%s%d", var.module_name, count.index)
  location                  = data.azurerm_resource_group.this.location
  resource_group_name       = data.azurerm_resource_group.this.name
  network_security_group_id = var.network_security_group_id
  tags                      = var.tags

  ip_configuration {
    name                          = format("%s%d", var.module_name, count.index)
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.this[count.index].id
  }
}

resource "azurerm_virtual_machine" "this" {
  count = var.instance_count

  name                          = format("%s%d", var.module_name, count.index)
  location                      = data.azurerm_resource_group.this.location
  resource_group_name           = data.azurerm_resource_group.this.name
  network_interface_ids         = [azurerm_network_interface.this[count.index].id]
  vm_size                       = var.vm_size
  delete_os_disk_on_termination = true
  dynamic "storage_image_reference" {
    for_each = [var.storage_image_reference]
    content {
      id        = lookup(storage_image_reference.value, "id", null)
      offer     = lookup(storage_image_reference.value, "offer", null)
      publisher = lookup(storage_image_reference.value, "publisher", null)
      sku       = lookup(storage_image_reference.value, "sku", null)
      version   = lookup(storage_image_reference.value, "version", null)
    }
  }
  tags = var.tags

  storage_os_disk {
    name              = format("%s%d", var.module_name, count.index)
    caching           = "ReadWrite"
    create_option     = "FromImage"
    disk_size_gb      = var.os_disk_size_gb
    managed_disk_type = var.os_managed_disk_type
  }

  os_profile {
    computer_name = format(
      "ip-%s.%s",
      join(
        "-",
        split(
          ".",
          azurerm_network_interface.this[count.index].private_ip_address,
        ),
      ),
      var.domain,
    )
    admin_username = var.default_user
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      key_data = var.key_data
      path     = format("/home/%s/.ssh/authorized_keys", var.default_user)
    }
  }
}
