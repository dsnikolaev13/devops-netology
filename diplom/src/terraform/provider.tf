variable "domain_name" {
    type        = string
    description = "Наименование основного домена"
}

variable "sa_access_key" {
    type        = string
    description = "Ключ доступа для сервисного аккаунта"
}

variable "sa_secret_key" {
    type        = string
    description = "Секретка для ключа доступа сервисного аккаунта"
}

variable "yc_folder_id" {
    type        = string
    description = "Идентификатор каталога"
}

terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.75.0"


  backend "s3" {
  }

}

provider "yandex" {
  folder_id = var.yc_folder_id
  service_account_key_file = file("nikolaev-diplom.json")
  #cloud_id  = "$(var.yc_cloud_id)"
  #zone      = "$(var.yc_zone)"
}
