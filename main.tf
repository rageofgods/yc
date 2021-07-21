terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  backend "s3" {} # We can't define variables here ;( So, it'll populated through parent jenkins job
}

variable "yc_token" {} # YaC auth token
variable "yc_cloud_id" {} # YaC target cloud id
variable "yc_folder_id" {} # YaC target folder id
variable "ssh_key" {} # Public ssh key for VM bootstrap with ansible
variable "ssh_private_key" {default = "terraform.key"} # From jenkins pipeline
variable "ssh_username" {default = "vm-admin"} # Username for ansible play
variable "yc_zone" {default = "ru-central1-b"} # Default cloud region
variable "yc_vm_name" {default = "jenkins"} # Provisioned VM name
variable "yc_vm_disk_size" {default = "20"} # VM disk size (system partition)
variable "yc_vm_cores" {default = "2"} # VM cpu cores count
variable "yc_vm_memory" {default = "4"} # VM memory in GB
variable "yc_image_id" {default = "fd8g0dj6sus84bcku631"} # yc compute image list --folder-id standard-images
variable "anbl_plbk_name" {default = "jenkins-provision"} # which playbook we want to run after inf provision
variable "yc_vm_platform" {default = "standard-v2"} #https://cloud.yandex.ru/docs/compute/concepts/vm-platforms

provider "yandex" {
  token     = "${var.yc_token}"
  cloud_id  = "${var.yc_cloud_id}"
  folder_id = "${var.yc_folder_id}"
  zone      = "${var.yc_zone}"
}

# Get YaC default subnet for target region
data "yandex_vpc_subnet" "subnet" {
  name = "default-${var.yc_zone}"
}

resource "yandex_compute_instance" "vm-1" {
  name = "${var.yc_vm_name}"
  platform_id = "${var.yc_vm_platform}"
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
    //subnet_id = yandex_vpc_subnet.subnet-1.id
    subnet_id = data.yandex_vpc_subnet.subnet.id
    nat       = true # Auto create external ip (with nat rule pointing to internal VM ip address
  }

  metadata = {
    user-data = "#cloud-config\nusers:\n  - name: ${var.ssh_username}\n    groups: sudo\n    shell: /bin/bash\n    sudo: ['ALL=(ALL) NOPASSWD:ALL']\n    ssh-authorized-keys:\n      - ${var.ssh_key}"
  }

  /*provisioner "remote-exec" {
    inline = ["uname -a"]

    connection {
      type        = "ssh"
      host        = "${self.network_interface.0.nat_ip_address}" # Use network_interface.0.ip_address in YaC on-prem env
      user        = "${var.ssh_username}"
      private_key = "${file(var.ssh_private_key)}"
    }
  }

  provisioner "local-exec" {
      command = "ansible-playbook -u ${var.ssh_username} -i '${self.network_interface.0.nat_ip_address},' --private-key ${var.ssh_private_key} --extra-vars 'jenkins_hostname=${self.network_interface.0.nat_ip_address}' jenkins-provision.yaml"
  }*/
}

/*resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "${var.yc_zone}"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}*/

output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.ip_address
}

output "external_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
}

output "fqdn_vm_1" {
  value = yandex_compute_instance.vm-1.fqdn
}