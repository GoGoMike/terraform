terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
      version = "1.48.0"
    }
  }
}
provider "openstack" {
    cloud = "default"
}

resource "openstack_compute_keypair_v2" "service-key" {
  name       = "service"
  public_key = "${file("${var.ssh_key_file}.pub")}"
}

resource "openstack_networking_network_v2" "network" {
name = "service-network"
admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "subnet" {
name = "service-subnet"
network_id = "${openstack_networking_network_v2.network.id}"
cidr = "174.24.1.0/24"
ip_version = 4
dns_nameservers = ["8.8.8.8","8.8.4.4"]
}

resource "openstack_networking_router_v2" "router" {
name = "service"
admin_state_up = "true"
external_network_id = "${var.external_network_id}"
}

resource "openstack_networking_router_interface_v2" "terraform" {
router_id = "${openstack_networking_router_v2.router.id}"
subnet_id = "${openstack_networking_subnet_v2.subnet.id}"
}

resource "openstack_compute_secgroup_v2" "secgroup" {
name = "service"
description = "Security group for Service VM"
rule {
from_port = 22
to_port = 22
ip_protocol = "tcp"
cidr = "0.0.0.0/0"
}

rule {
from_port = -1
to_port = -1
ip_protocol = "icmp"
cidr = "0.0.0.0/0"
}
}

resource "openstack_networking_floatingip_v2" "floating_ip" {
pool = "${var.pool}"
depends_on = [openstack_networking_router_interface_v2.terraform]
}

resource "openstack_compute_instance_v2" "service-vm" {
  name            = "service-vm-${var.cluster}"
  image_name      = "${var.image}"
  flavor_name     = "${var.flavor}"
  key_pair        = "${openstack_compute_keypair_v2.service-key.name}"
  security_groups = [ "${openstack_compute_secgroup_v2.secgroup.name}" ]

  network {
    uuid = "${openstack_networking_network_v2.network.id}"
  }
}

resource "openstack_compute_floatingip_associate_v2" "fip_attach" {
  floating_ip = "${openstack_networking_floatingip_v2.floating_ip.address}"
  instance_id = "${openstack_compute_instance_v2.service-vm.id}"
}

output "address" {
value = "${openstack_networking_floatingip_v2.floating_ip.address}"
}
