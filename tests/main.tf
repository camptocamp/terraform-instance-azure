locals {
  default_user    = "debian"
  image_publisher = "credativ"
  image_offer     = "Debian"
  image_sku       = "9-backports"
}

###
# Variables
#
variable "key_pair" {}

###
# Datasources
#
data "pass_password" "puppet_autosign_psk" {
  path = "terraform/c2c_mgmtsrv/puppet_autosign_psk"
}

data "pass_password" "openstack" {
  path = "terraform/openstack/cloud.camptocamp.com/sandbox"
}

###
# Code to test
#
resource "azurerm_resource_group" "test" {
  name     = "acceptanceTest"
  location = "France Central"
}

resource "azurerm_virtual_network" "test" {
  name                = "acceptanceTest"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.test.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"
}

resource "azurerm_subnet" "test" {
  name                 = "acceptanceTest"
  resource_group_name  = "${azurerm_resource_group.test.name}"
  virtual_network_name = "${azurerm_virtual_network.test.name}"
  address_prefix       = "10.0.2.0/24"
}

module "instance" {
  source         = "../"
  module_name    = "acceptanceTest"
  instance_count = 1

  storage_image_reference {
    publisher = "${local.image_publisher}"
    offer     = "${local.image_offer}"
    sku       = "${local.image_sku}"
    version   = "latest"
  }

  instance_type = "Standard_B2ms"
  default_user  = "${local.default_user}"
  domain        = "azure.cloud.camptocamp.com"
  location      = "${azurerm_resource_group.test.location}"
  rg_name       = "${azurerm_resource_group.test.name}"
  subnet_id     = "${azurerm_subnet.test.id}"
}

module "puppet-node" {
  source = "git::ssh://git@github.com/camptocamp/terraform-puppet-node.git"

  instances = [
    for i in range(length(module.instance.this_instance_hostname)) :
    {
      hostname = module.instance.this_instance_hostname
      connection = {
        host = coalesce(module.instance.this_instance_public_ipv4[i], module.instance.this_instance_public_ipv6[i])
      }
    }
  ]

  puppet = {
    autosign_psk = "${data.pass_password.puppet_autosign_psk.data["puppet_autosign_psk"]}"
    role         = "base"
    environment  = "staging4"
    server       = "puppet.camptocamp.net"
    caserver     = "puppetca.camptocamp.net"
  }
}

###
# Acceptance test
#
resource "null_resource" "acceptance" {
  connection {
    host = "${element(module.puppet-node.azurerm_public_ip.puppet-node.*.ip_address, count.index)}"
    type = "ssh"
    user = "${local.default_user}"
  }

  depends_on = ["module.puppet-node"]

  provisioner "file" {
    source      = "script.sh"
    destination = "/tmp/script.sh"
  }

  provisioner "file" {
    source      = "goss.yaml"
    destination = "/home/${local.default_user}/goss.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/script.sh",
      "sudo /tmp/script.sh",
    ]
  }
}
