
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
    #nat_ip_address = yandex_vpc_address..external_ipv4_address[0].address
  }

  metadata = {
    user-data = templatefile("${path.module}/cloud-init.yml.tftpl", {
      db_host = yandex_mdb_postgresql_cluster.mypg.host[0].fqdn
      db_name = yandex_mdb_postgresql_database.db.name
      db_user = yandex_mdb_postgresql_user.user.name
      db_pswd = yandex_mdb_postgresql_user.user.password
      ssh-key = "${file("~/.ssh/id_rsa.pub")}"
      redis_url =  "redis://pswdpswd@${yandex_mdb_redis_cluster.redis_cluster.host[0].fqdn}:6379"
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

# Дашборд для мониторинга
data "yandex_monitoring_dashboard" "my_dashboard" {
  dashboard_id = yandex_monitoring_dashboard.my-dashboard.id
  folder_id   = var.yc_folder_id
}

resource "yandex_monitoring_dashboard" "my-dashboard" {
  name        = "local-id-resource"
  description = "Description"
  title       = "My title"
  folder_id   = var.yc_folder_id
  labels = {
    a = "b"
  }
  parametrization {
    selectors = "a=b"
    parameters {
      description = "param1 description"
      title       = "title"
      hidden      = false
      id          = "param1"
      custom {
        default_values  = ["1", "2"]
        values          = ["1", "2", "3"]
        multiselectable = true
      }
    }
    parameters {
      hidden = true
      id     = "param2"
      label_values {
        default_values  = ["1", "2"]
        multiselectable = true
        label_key       = "key"
        selectors       = "a=b"
      }
    }
    parameters {
      hidden = true
      id     = "param3"
      text {
        default_value = "abc"
      }
    }
  }
  widgets {
    text {
      text = "text here"
    }
    position {
      h = 1
      w = 1
      x = 4
      y = 4
    }
  }
  widgets {
    chart {
      description    = "chart description"
      title          = "title for chart"
      chart_id       = "chart1id"
      display_legend = true
      freeze         = "FREEZE_DURATION_HOUR"
      name_hiding_settings {
        names    = ["a", "b"]
        positive = true
      }
      queries {
        downsampling {
          disabled         = false
          gap_filling      = "GAP_FILLING_NULL"
          grid_aggregation = "GRID_AGGREGATION_COUNT"
          max_points       = 100
        }
        target {
          hidden    = true
          text_mode = true
          query     = "{service=monitoring}"
        }
      }
      series_overrides {
        name = "name"
        settings {
          color          = "colorValue"
          grow_down      = true
          name           = "series_overrides name"
          type           = "SERIES_VISUALIZATION_TYPE_LINE"
          yaxis_position = "YAXIS_POSITION_LEFT"
          stack_name     = "stack name"
        }
      }
      visualization_settings {
        aggregation = "SERIES_AGGREGATION_AVG"
        interpolate = "INTERPOLATE_LEFT"
        type        = "VISUALIZATION_TYPE_POINTS"
        normalize   = true
        show_labels = true
        title       = "visualization_settings title"
        color_scheme_settings {
          gradient {
            green_value  = "11"
            red_value    = "22"
            violet_value = "33"
            yellow_value = "44"
          }
        }
        heatmap_settings {
          green_value  = "1"
          red_value    = "2"
          violet_value = "3"
          yellow_value = "4"
        }
        yaxis_settings {
          left {
            max         = "111"
            min         = "11"
            title       = "yaxis_settings left title"
            precision   = 3
            type        = "YAXIS_TYPE_LOGARITHMIC"
            unit_format = "UNIT_CELSIUS"
          }
          right {
            max         = "22"
            min         = "2"
            title       = "yaxis_settings right title"
            precision   = 2
            type        = "YAXIS_TYPE_LOGARITHMIC"
            unit_format = "UNIT_NONE"
          }
        }
      }
    }
    position {
      h = 100
      w = 100
      x = 6
      y = 6
    }
  }
  widgets {
    title {
      text = "title here"
      size = "TITLE_SIZE_XS"
    }
    position {
      h = 1
      w = 1
      x = 1
      y = 1
    }
  }
}


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
  name                = "redis_cluster"
  environment         = "PRESTABLE"
  network_id          = yandex_vpc_network.network.id
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
    zone             = var.yc_zone
    subnet_id        = yandex_vpc_subnet.subnetwork.id
  }
}





