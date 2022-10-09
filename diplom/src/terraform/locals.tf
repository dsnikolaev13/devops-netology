locals {
  yc_instance_type_map = {
    stage = "standard-v1"
    prod  = "standard-v2"
  }
  yc_cores = {
    stage = 2
    prod  = 4
  }
  yc_disk_size = {
    stage = 20
    prod  = 30
  }
  yc_instance_count = {
    stage = 1
    prod  = 1
  }
  yc_mem = {
    stage = 4
    prod  = 8
  }
  vpc_zone = {
    stage = "ru-central1-b"
    prod  = "ru-central1-a"
  }
  vpc_subnets_v4-cidr = {
    stage = ["10.128.1.0/24"]
    prod  = ["192.168.1.0/24"]
  }
}