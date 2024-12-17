variable "yc_token" {
    default="t1.9euelZrLlM3PiomJysmeio3Nz52Nye3rnpWals2VksmalM-RlcnJkpSJzJjl8_dZVHhE-e9ZVmpI_d3z9xkDdkT571lWakj9zef1656VmouQzonLjZWVk46Uy5CYksrK7_zF656VmouQzonLjZWVk46Uy5CYksrK.50Sjmx3mG2sGoQ-WC9glUVYVmq3GlZT2xOVJzgiAIekYFZQzKDkrDwpDiyWcmOpcVSWw7uG29jzRlHhIJEpCDQ"
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
