terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  backend "s3" {}
}

variable "yc_token" {}
variable "yc_cloud_id" {}
variable "yc_folder_id" {}

provider "yandex" {
  token     = "${var.yc_token}"
  cloud_id  = "${var.yc_cloud_id}"
  folder_id = "${var.yc_folder_id}"
  zone      = "ru-central1-b"
}

variable "ssh_key" {}
variable "ssh_private_key" {default = "terraform.key"}

resource "yandex_compute_instance" "vm-1" {
  name = "terraform1"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8g0dj6sus84bcku631"
      size     = "20"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    user-data = "#cloud-config\nusers:\n  - name: vm-admin\n    groups: sudo\n    shell: /bin/bash\n    sudo: ['ALL=(ALL) NOPASSWD:ALL']\n    ssh-authorized-keys:\n      - ${var.ssh_key}"
  }

  provisioner "remote-exec" {
    inline = ["uname -a"]

    connection {
      type        = "ssh"
      host        = "${self.network_interface.0.nat_ip_address}"
      user        = "vmadmin"
      private_key = "${file(var.ssh_private_key)}"
    }
  }

  provisioner "local-exec" {
      command = "echo 'hello'"
  }

  //metadata = {
  //  ssh-keys = "${var.ssh_key}"
  //}
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.ip_address
}

output "external_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
}

output "subnet-1" {
  value = yandex_vpc_subnet.subnet-1.id
}