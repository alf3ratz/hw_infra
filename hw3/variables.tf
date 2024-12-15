variable "yc_token" {
    default="y0_AgAAAAAiHjY3AATuwQAAAAEZ2Mh6AAD7BmEyquNGHrTGvCVmhfGflpFYbQ"
}
variable "yc_cloud_id" {
    default="b1g9gvqep08q3gcm3qd1"
}
variable "yc_folder_id" {
    default="b1gs1mnpsgc0ud5le3h4"
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
