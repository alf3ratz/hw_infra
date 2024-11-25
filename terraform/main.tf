
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone
}


resource "yandex_vpc_network" "network" {
  name = "network"
}

resource "yandex_vpc_subnet" "subnetwork" {
  name           = "subnetwork"
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

data "yandex_compute_image" "image" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_disk" "boot-disk" {
  name     = "boot-disk"
  zone     = var.yc_zone
  size     = 10
  image_id = data.yandex_compute_image.image.id
}

# Виртуальная машина
resource "yandex_compute_instance" "virtual-machine" {
  name        = "virtual-machine"
  platform_id = "standard-v3"
  resources {
    cores  = 2
    memory = 4
  }
  boot_disk {
    disk_id = yandex_compute_disk.boot-disk.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnetwork.id
    nat       = true
  }
}

# Сервисный аккаунт
resource "yandex_iam_service_account" "service-account" {
  name = "service-account"
}

# Роли для сервисного аккаунта
resource "yandex_resourcemanager_folder_iam_member" "service-account-roles" {
  folder_id = var.yc_folder_id
  role = "storage.editor"
  member = "serviceAccount:${yandex_iam_service_account.service-account.id}"
}

# Статический ключ для сервисного аккаунта
resource "yandex_iam_service_account_static_access_key" "sa-key" {
  service_account_id = yandex_iam_service_account.service-account.id
}

# Объектное хранилище
resource "yandex_storage_bucket" "bucket" {
  bucket = "terraform-bucket-${random_string.bucket_name.result}"
  access_key = yandex_iam_service_account_static_access_key.sa-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-key.secret_key

  depends_on = [ yandex_resourcemanager_folder_iam_member.service-account-roles ]
}

resource "random_string" "bucket_name" {
  length  = 8
  special = false
  upper   = false
} 

resource "yandex_ydb_database_serverless" "db" {
  name = "ydb-serverless"
}

