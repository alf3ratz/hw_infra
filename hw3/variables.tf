variable "yc_token" {
    default=""
}
variable "yc_cloud_id" {
    default=""
}
variable "yc_folder_id" {
    default=""
}
variable "yc_zone" {
    default="ru-central1-a"
}
variable "zones" {
  description = "(Optional) - Yandex Cloud Zones for provisoned resources."
  type        = set(string)
  default     = ["ru-central1-b", "ru-central1-d"]
}

variable "subnets" {
  description = "(Optional) - A map of AZ to subnets CIDR block ranges."
  type        = map(list(string))
  default = {
    "ru-central1-b" = ["192.168.11.0/24"],
    "ru-central1-d" = ["192.168.12.0/24"]   
  }
} 
