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
variable "ssh_key" {}
variable "ssh_private_key" {default = "terraform.key"} # From jenkins pipeline
variable "ssh_username" {default = "vm-admin"}
variable "yc_zone" {default = "ru-central1-b"}
variable "yc_vm_name" {default = "jenkins"}
variable "yc_vm_disk_size" {default = "20"}
variable "yc_vm_cores" {default = "2"}
variable "yc_vm_memory" {default = "4"}
variable "yc_image_id" {default = "fd8g0dj6sus84bcku631"} # yc compute image list --folder-id standard-images

provider "yandex" {
  token     = "${var.yc_token}"
  cloud_id  = "${var.yc_cloud_id}"
  folder_id = "${var.yc_folder_id}"
  zone      = "${var.yc_zone}"
}

resource "yandex_compute_instance" "vm-1" {
  name = "${var.yc_vm_name}"
  hostname = "${var.yc_vm_name}"
  allow_stopping_for_update = true # Debug only!

  resources {
    cores  = "${var.yc_vm_cores}"
    memory = "${var.yc_vm_memory}"
  }

  boot_disk {
    initialize_params {
      image_id = "${var.yc_image_id}"
      size     = "${var.yc_vm_disk_size}"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true # For external communications
  }

  metadata = {
    user-data = "#cloud-config\nusers:\n  - name: ${var.ssh_username}\n    groups: sudo\n    shell: /bin/bash\n    sudo: ['ALL=(ALL) NOPASSWD:ALL']\n    ssh-authorized-keys:\n      - ${var.ssh_key}"
  }

  provisioner "remote-exec" {
    inline = ["uname -a"]

    connection {
      type        = "ssh"
      host        = "${self.network_interface.0.nat_ip_address}" # Use network_interface.0.ip_address in YaC on-prem env
      user        = "${var.ssh_username}"
      private_key = "${file(var.ssh_private_key)}"
    }
  }

  provisioner "local-exec" {
      command = "ansible-galaxy install emmetog.jenkins && ansible-playbook -i '${self.network_interface.0.nat_ip_address},' --private-key ${var.ssh_private_key} jenkins-provision.yml"
  }
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "${var.yc_zone}"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.ip_address
}

output "external_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
}

output "fqdn_vm_1" {
  value = yandex_compute_instance.vm-1.fqdn
}