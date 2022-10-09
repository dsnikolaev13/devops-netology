resource "yandex_compute_instance" "gitlab" {
  name = "gitlab"
  hostname = "gitlab.nikolaev63.ru"
  platform_id = local.yc_instance_type_map[terraform.workspace]
  zone = local.vpc_zone[terraform.workspace]
    resources {
    core_fraction = 20
    cores  = 4
    memory = 8
      }
    scheduling_policy {
    preemptible = true
}

  boot_disk {
    initialize_params {
      image_id = "fd8f1tik9a7ap9ik2dg1" //Ubunutu2004
      size = local.yc_disk_size[terraform.workspace]
    }

  }
  network_interface {
    subnet_id = yandex_vpc_subnet.yc_subnet.id
    nat       = false
    ip_address = "192.168.1.13"
  }
  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")} \nubuntu:${file("~/.ssh/diman.pub")} \nubuntu:${file("~/.ssh/vpcnginx.pub")}"
    serial-port-enable=1
  }

}
