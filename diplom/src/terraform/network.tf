resource "yandex_vpc_network" "yc_network" {
  name = "vpc-network-${terraform.workspace}"
  }

resource "yandex_vpc_subnet" "yc_subnet" {
  name           = "yc_subnet"
  zone           = local.vpc_zone[terraform.workspace]
  network_id     = yandex_vpc_network.yc_network.id
  v4_cidr_blocks = local.vpc_subnets_v4-cidr[terraform.workspace]
  route_table_id = yandex_vpc_route_table.route-table-nat-inet.id
}

resource "yandex_vpc_route_table" "route-table-nat-inet" {
    name = "route-table-nat-inet"
    network_id = "${yandex_vpc_network.yc_network.id}"
    static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address = "192.168.1.12"
    }
  }