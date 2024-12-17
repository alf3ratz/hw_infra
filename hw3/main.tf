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

provider "random" {}

data "yandex_compute_image" "image" {
  image_id = "fd8d16o0fku50qt0g8hl"
}

resource "yandex_vpc_network" "network" {
  name = "network"
}

resource "yandex_vpc_subnet" "subnetwork-to-each-zone" {
  for_each = var.zones
  name     = "subnetwork-${each.key}"
  zone     = each.value
  v4_cidr_blocks = var.subnets[each.value]
  network_id     = yandex_vpc_network.network.id
}

# Внешний IP-адрес для каждой зоны
resource "yandex_vpc_address" "address-to-each-zone" {
  for_each = var.subnets
  name     = "vm_address-${each.key}"
  external_ipv4_address {
    zone_id = each.key
  }
}

resource "yandex_vpc_address" "address-to-each-zone-2" {
  for_each = var.subnets
  name     = "vm_address-2-${each.key}"
  external_ipv4_address {
    zone_id = each.key
  }
}

# Диски для виртуальных машин в каждой зоне
resource "yandex_compute_disk" "boot-disk-to-each-zone" {
  for_each = var.subnets
  name     = "boot-disk-${each.key}"
  zone     = each.key
  image_id = data.yandex_compute_image.image.id
  size     = 10
}

resource "yandex_compute_disk" "boot-disk-to-each-zone-2" {
  for_each = var.subnets
  name     = "boot-disk-2${each.key}"
  zone     = each.key
  image_id = data.yandex_compute_image.image.id
  size     = 10
}


resource "yandex_compute_instance" "virtual-machine-with-redis-pusher" {
  for_each = var.zones
  name     = "pusher-vm-${each.key}"
  zone     = each.value
  platform_id = "standard-v3"
  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-to-each-zone-2[each.key].id
  }

  network_interface {
    subnet_id      = yandex_vpc_subnet.subnetwork-to-each-zone[each.key].id
    nat            = true
    nat_ip_address = yandex_vpc_address.address-to-each-zone-2[each.key].external_ipv4_address[0].address
  }

  metadata = {
    user-data = templatefile("${path.module}/cloud-init.yml.tftpl", {
      db_host = yandex_mdb_postgresql_cluster.mypg.host[0].fqdn
      db_name = yandex_mdb_postgresql_database.db.name
      db_user = yandex_mdb_postgresql_user.user.name
      db_pswd = yandex_mdb_postgresql_user.user.password
      # db_host = "sdf"
      # db_name = "fds"
      # db_user="dsfsd"
      # db_pswd="dsf"
      # redis_url="fsdf"
      ssh-key = "${file("~/.ssh/id_rsa.pub")}"
      redis_url = "redis://pswdpswd@${yandex_mdb_redis_cluster.redis_cluster[each.key].host[0].fqdn}:6379"
    })
  }
}

resource "yandex_compute_instance" "virtual-machine-to-each-zone" {
  for_each = var.subnets
  name     = "vm-${each.key}"
  zone     = each.key
  platform_id = "standard-v3"
  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-to-each-zone[each.key].id
  }

  network_interface {
    subnet_id      = yandex_vpc_subnet.subnetwork-to-each-zone[each.key].id
    nat            = true
    nat_ip_address = yandex_vpc_address.address-to-each-zone[each.key].external_ipv4_address[0].address
  }

  metadata = {
    user-data = templatefile("${path.module}/cloud-to-each-zone-init.yml.tftpl", {
      db_host = yandex_mdb_postgresql_cluster.mypg.host[0].fqdn
      db_name = yandex_mdb_postgresql_database.db.name
      db_user = yandex_mdb_postgresql_user.user.name
      db_pswd = yandex_mdb_postgresql_user.user.password
      # db_host = "sdf"
      # db_name = "fds"
      # db_user="dsfsd"
      # db_pswd="dsf"
      # redis_url="fsdf"
      ssh-key = "${file("~/.ssh/id_rsa.pub")}"
      redis_url =  "redis://pswdpswd@${yandex_mdb_redis_cluster.redis_cluster[each.key].host[0].fqdn}:6379"
    })
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

resource "random_string" "bucket_name" {
  length  = 8
  special = false
  upper   = false
}

resource "yandex_mdb_postgresql_cluster" "mypg" {
  name                = "mypg"
  environment         = "PRESTABLE"
  network_id          = yandex_vpc_network.network.id
  config {
    version = 17
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = "10"
    }
    access {
      data_lens = true
      web_sql   = true
    }
  }

  host {
    zone      = "ru-central1-b"
    name      = "mypg-host-a"
    subnet_id = yandex_vpc_subnet.subnetwork-to-each-zone["ru-central1-b"].id
  }
}

resource "yandex_mdb_postgresql_database" "db" {
  cluster_id = yandex_mdb_postgresql_cluster.mypg.id
  name       = "db"
  owner      = yandex_mdb_postgresql_user.user.name
}

resource "yandex_mdb_postgresql_user" "user" {
  cluster_id = yandex_mdb_postgresql_cluster.mypg.id
  name       = "user1337"
  password   = "user1337pswd"
}

resource "yandex_mdb_redis_cluster" "redis_cluster" {
  environment         = "PRESTABLE"
  network_id          = yandex_vpc_network.network.id
  for_each            = var.zones
  name                = "redis-name-${each.key}"

  tls_enabled         = false
  announce_hostnames  = true

  config {
    version      = "7.2"
    password     = "pswdpswd"
  }

  resources {
    resource_preset_id = "hm3-c2-m8"
    disk_type_id       = "network-ssd"
    disk_size          = 16
  }

  host {
    zone             = each.value
    subnet_id        = yandex_vpc_subnet.subnetwork-to-each-zone[each.key].id
  }
}
