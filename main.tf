data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "random_string" "instance_id" {
  count = var.force_module_name ? 0 : 1

  length  = 6
  special = false
}

resource "azurerm_public_ip" "this" {
  count = var.instance_count

  name                = var.force_module_name ? format("%s%d", var.module_name, count.index) : format("%s-%s-%d", var.module_name, random_string.instance_id[0].result, count.index)
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  allocation_method   = "Static"
  tags                = var.tags
}

resource "azurerm_network_interface" "this" {
  count = var.instance_count

  name                      = var.force_module_name ? format("%s%d", var.module_name, count.index) : format("%s-%s-%d", var.module_name, random_string.instance_id[0].result, count.index)
  location                  = data.azurerm_resource_group.this.location
  resource_group_name       = data.azurerm_resource_group.this.name
  tags                      = var.tags

  ip_configuration {
    name                          = var.force_module_name ? format("%s%d", var.module_name, count.index) : format("%s-%s-%d", var.module_name, random_string.instance_id[0].result, count.index)
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this[count.index].id
  }
}

resource "azurerm_network_interface_security_group_association" "this" {
  count                     = var.instance_count
  network_interface_id      = azurerm_network_interface.this[count.index].id
  network_security_group_id = var.network_security_group_id
}

resource "azurerm_virtual_machine" "this" {
  count = var.instance_count

  name                          = var.force_module_name ? format("%s%d", var.module_name, count.index) : format("%s-%s-%d", var.module_name, random_string.instance_id[0].result, count.index)
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
    name              = var.force_module_name ? format("%s%d", var.module_name, count.index) : format("%s-%s-%d", var.module_name, random_string.instance_id[0].result, count.index)
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

resource "null_resource" "this" {
  count = var.instance_count

  connection {
    type                = lookup(var.connection, "type", null)
    user                = lookup(var.connection, "user", "terraform")
    password            = lookup(var.connection, "password", null)
    host                = azurerm_public_ip.this[count.index].ip_address
    port                = lookup(var.connection, "port", 22)
    timeout             = lookup(var.connection, "timeout", null)
    script_path         = lookup(var.connection, "script_path", null)
    private_key         = lookup(var.connection, "private_key", null)
    agent               = lookup(var.connection, "agent", null)
    agent_identity      = lookup(var.connection, "agent_identity", null)
    host_key            = lookup(var.connection, "host_key", null)
    https               = lookup(var.connection, "https", null)
    insecure            = lookup(var.connection, "insecure", null)
    use_ntlm            = lookup(var.connection, "use_ntlm", null)
    cacert              = lookup(var.connection, "cacert", null)
    bastion_host        = lookup(var.connection, "bastion_host", null)
    bastion_host_key    = lookup(var.connection, "bastion_host_key", null)
    bastion_port        = lookup(var.connection, "bastion_port", 22)
    bastion_user        = lookup(var.connection, "bastion_user", null)
    bastion_password    = lookup(var.connection, "bastion_password", null)
    bastion_private_key = lookup(var.connection, "bastion_private_key", null)
  }

  provisioner "ansible" {
    plays {
      playbook {
        file_path = "${path.module}/ansible-data/playbook.yaml"
      }

      diff = true

      extra_vars = {
        hostname = format(
          "ip-%s",
          join(
            "-",
            split(
              ".",
              azurerm_network_interface.this[count.index].private_ip_address,
            ),
          ),
        )
        domain_name = var.domain
      }
    }

    ansible_ssh_settings {
      connect_timeout_seconds = 60
      insecure_no_strict_host_key_checking = true
    }
  }

  depends_on = [azurerm_virtual_machine.this]
}

#########
# Puppet

module "puppet-node" {
  source         = "git::https://github.com/camptocamp/terraform-puppet-node.git?ref=v1.x"
  instance_count = var.puppet == null ? 0 : var.instance_count

  instances = [
    for i in range(length(azurerm_virtual_machine.this)) :
    {
      hostname = format(
        "ip-%s.%s",
        join(
          "-",
          split(".", azurerm_network_interface.this[i].private_ip_address),
        ),
        var.domain,
      )

      connection = {
        host                = azurerm_public_ip.this[i].ip_address
        type                = lookup(var.connection, "type", null)
        user                = lookup(var.connection, "user", "terraform")
        password            = lookup(var.connection, "password", null)
        port                = lookup(var.connection, "port", 22)
        timeout             = lookup(var.connection, "timeout", "")
        script_path         = lookup(var.connection, "script_path", null)
        private_key         = lookup(var.connection, "private_key", null)
        agent               = lookup(var.connection, "agent", null)
        agent_identity      = lookup(var.connection, "agent_identity", null)
        host_key            = lookup(var.connection, "host_key", null)
        https               = lookup(var.connection, "https", false)
        insecure            = lookup(var.connection, "insecure", false)
        use_ntlm            = lookup(var.connection, "use_ntlm", false)
        cacert              = lookup(var.connection, "cacert", null)
        bastion_host        = lookup(var.connection, "bastion_host", null)
        bastion_host_key    = lookup(var.connection, "bastion_host_key", null)
        bastion_port        = lookup(var.connection, "bastion_port", 22)
        bastion_user        = lookup(var.connection, "bastion_user", null)
        bastion_password    = lookup(var.connection, "bastion_password", null)
        bastion_private_key = lookup(var.connection, "bastion_private_key", null)
      }
    }
  ]

  server_address    = var.puppet != null ? lookup(var.puppet, "server_address", null) : ""
  server_port       = var.puppet != null ? lookup(var.puppet, "server_port", 443) : -1
  ca_server_address = var.puppet != null ? lookup(var.puppet, "ca_server_address", null) : ""
  ca_server_port    = var.puppet != null ? lookup(var.puppet, "ca_server_port", 443) : -1
  environment       = var.puppet != null ? lookup(var.puppet, "environment", null) : ""
  role              = var.puppet != null ? lookup(var.puppet, "role", null) : ""
  autosign_psk      = var.puppet != null ? lookup(var.puppet, "autosign_psk", null) : ""

  deps_on = var.puppet != null ? null_resource.this[*].id : []
}
