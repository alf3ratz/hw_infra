
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

provider "random" {
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

resource "yandex_vpc_subnet" "subnetwork-to-each-zone" {
  for_each = var.zones
  name           = keys(var.subnets)[index(tolist(var.zones), each.value)]
  zone           = each.value
  v4_cidr_blocks = var.subnets[each.value]
  network_id     = yandex_vpc_network.network.id
}

resource "yandex_vpc_address" "address-to-each-zone" {
  for_each = var.zones
  name = length(var.zones) > 1 ? "$vm-address-${substr(each.value, -1, 0)}" : "vm-address"
  external_ipv4_address {
    zone_id = each.value
  }
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

resource "yandex_compute_disk" "boot-disk-to-each-zone" {
  for_each = var.zones
  name     = length(var.zones) > 1 ? "boot-disk-${substr(each.value, -1, 0)}" : "boot-disk"
  zone     = each.value
  image_id = data.yandex_compute_image.image.id
  size = 10
}

# Виртуальная машина, которая добавляет записи в редис
resource "yandex_compute_instance" "virtual-machine-with-redis-pusher" {
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
    #nat_ip_address = yandex_vpc_address..external_ipv4_address[0].address
  }

  metadata = {
    user-data = templatefile("${path.module}/cloud-init.yml.tftpl", {
      db_host = yandex_mdb_postgresql_cluster.mypg.host[0].fqdn
      db_name = yandex_mdb_postgresql_database.db.name
      db_user = yandex_mdb_postgresql_user.user.name
      db_pswd = yandex_mdb_postgresql_user.user.password
      ssh-key = "${file("~/.ssh/id_rsa.pub")}"
      redis_url =  "redis://pswdpswd@${yandex_mdb_redis_cluster.redis_cluster[0].host[0].fqdn}:6379"
    }) 
  }
}


resource "yandex_compute_instance" "virtual-machine-to-each-zone" {
  for_each = var.zones
  name     = length(var.zones) > 1 ? "$vm-${substr(each.value, -1, 0)}" : "vm"
  zone     = each.value
  platform_id = "standard-v3"
  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-to-each-zone[each.value].id
  }

  network_interface {
    subnet_id      = yandex_vpc_subnet.subnetwork-to-each-zone[each.value].id
    nat            = true
    nat_ip_address = yandex_vpc_address.address-to-each-zone[each.value].external_ipv4_address[0].address
  }

  metadata = {
    user-data = templatefile("${path.module}/cloud-to-each-zone-init.yml.tftpl", {
      db_host = yandex_mdb_postgresql_cluster.mypg.host[0].fqdn
      db_name = yandex_mdb_postgresql_database.db.name
      db_user = yandex_mdb_postgresql_user.user.name
      db_pswd = yandex_mdb_postgresql_user.user.password
      ssh-key = "${file("~/.ssh/id_rsa.pub")}"
      redis_url =  "redis://pswdpswd@${yandex_mdb_redis_cluster.redis_cluster[each.value].host[0].fqdn}:6379"
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

# Объектное хранилище
# resource "yandex_storage_bucket" "bucket" {
#   bucket = "terraform-bucket-${random_string.bucket_name.result}"
#   access_key = yandex_iam_service_account_static_access_key.sa-key.access_key
#   secret_key = yandex_iam_service_account_static_access_key.sa-key.secret_key

#   depends_on = [ yandex_resourcemanager_folder_iam_member.service-account-roles ]
# }

# resource "random_string" "bucket_name" {
#   length  = 8
#   special = false
#   upper   = false
# } 

# Кластер бд
resource "yandex_mdb_postgresql_cluster" "mypg" {
  name                = "mypg"
  environment         = "PRESTABLE"
  network_id          = yandex_vpc_network.network.id
  #security_group_ids  = [ yandex_vpc_security_group.pgsql-sg.id ]
  #deletion_protection = true

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
    zone      = var.yc_zone
    name      = "mypg-host-a"
    subnet_id = yandex_vpc_subnet.subnetwork.id
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
  for_each = var.zones
  name     = length(var.zones) > 1 ? "redis-name-${substr(each.value, -1, 0)}" : "redis-name"

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
    subnet_id        = yandex_vpc_subnet.subnetwork-to-each-zone[each.value].id
  }
}





