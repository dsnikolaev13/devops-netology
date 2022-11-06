# Дипломный практикум в YandexCloud

### 1. Зарегистрировать доменное имя (любое на ваш выбор в любой доменной зоне).

___

Зарегистрировали доменное имя в https://www.reg.ru/

nikolaev63.ru

### 2. Создание инфраструктуры

1. [Создайте сервисный аккаунт](https://cloud.yandex.ru/docs/iam/operations/sa/create), который будет в дальнейшем использоваться Terraform для работы с инфраструктурой с необходимыми и достаточными правами. Не стоит использовать права суперпользователя

Создаем сервис-аккаунт:
```bash
    ~/devopsdiplom/src/ansible  yc iam service-account create --name nikolaev-diplom 
id: aje*****************
folder_id: b1g*****************
created_at: "2022-09-03T10:29:26.352908008Z"
name: nikolaev-diplom

```
Назначим роль editor
```bash
    ~/devopsdiplom/src/ansible  yc resource-manager folder add-access-binding bb1g***************** --role editor --subject serviceAccount:aje*****************
done (1s)
```
Создадим статический ключ доступа
```bash
    ~/devopsdiplom/src/ansible  yc iam access-key create --service-account-name nikolaev-diplom
access_key:
  id: aje****
  service_account_id: aje****
  created_at: "2022-07-10T23:32:28.323165040Z"
  key_id: YCA**********************
secret: YCM**********************
```

2. Подготовьте [backend](https://www.terraform.io/docs/language/settings/backends/index.html) для Terraform. Остановим выбор на альтернативном варианте:  [S3 bucket в созданном YC аккаунте](https://cloud.yandex.ru/docs/storage/operations/buckets/create).
Создали бакет в YC:

![Бакет](src/screenshots/backend.png)

Конфигурация содержится в файле [provider.tf](./src/terraform/provider.tf):

```terraform
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
```

### 3. Настройка workspaces 

Создаем workspaces `prod` и `stage`:

```bash 
    ~/devopsdiplom/src/terraform  terraform workspace new prod
Created and switched to workspace "prod"!

You're now on a new, empty workspace. Workspaces isolate their state,
so if you run "terraform plan" Terraform will not see any existing state
for this configuration.
    ~/devopsdiplom/src/terraform  terraform workspace new stage
Created and switched to workspace "stage"!

You're now on a new, empty workspace. Workspaces isolate their state,
so if you run "terraform plan" Terraform will not see any existing state
for this configuration.
```

Проверяем наличие созданных workspace:
```bash
    ~/devopsdiplom/src/terraform  terraform workspace list                                                                       
  default
  prod
* stage

```
</details>

### 4. Создание VPC с подсетями в разных зонах доступности.

Подготовили tf. файлы: 
* `network.tf`
```terraform
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
```
</details>

### 5. Убедитесь, что теперь вы можете выполнить команды `terraform destroy` и `terraform apply` без дополнительных ручных действий.

Все ВМ успешно создаются, роли ansible успешно отрабатывают:

![Виртуальные машины](src/screenshots/VM.png)

---
### 6. Установка Nginx и LetsEncrypt

Необходимо разработать Ansible роль для установки Nginx и LetsEncrypt.

**Для получения LetsEncrypt сертификатов во время тестов своего кода пользуйтесь [тестовыми сертификатами](https://letsencrypt.org/docs/staging-environment/), так как количество запросов к боевым серверам LetsEncrypt [лимитировано](https://letsencrypt.org/docs/rate-limits/).**

Рекомендации:
  - Имя сервера: `mycompanyname.ru`
  - Характеристики: 2vCPU, 2 RAM, External address (Public) и Internal address.

Цель:

1. Создать reverse proxy с поддержкой TLS для обеспечения безопасного доступа к веб-сервисам по HTTPS.

Ожидаемые результаты:

1. В вашей доменной зоне настроены все A-записи на внешний адрес этого сервера:
    - `https://www.nikolaev63.ru` (WordPress)
    - `https://gitlab.nikolaev63.ru` (Gitlab)
    - `https://grafana.nikolaev63.ru` (Grafana)
    - `https://prometheus.nikolaev63.ru` (Prometheus)
    - `https://alertmanager.nikolaev63.ru` (Alert Manager)
2. Настроены все upstream для выше указанных URL, куда они сейчас ведут на этом шаге не важно, позже вы их отредактируете и укажите верные значения.
3. В браузере можно открыть любой из этих URL и увидеть ответ сервера (502 Bad Gateway). На текущем этапе выполнение задания это нормально!

___

1. 
[Резервирование статического IP-адреса по инструкции](https://cloud.yandex.ru/docs/vpc/operations/get-static-ip) 

2. 
Добавление А-записей в DNS нашей доменной зоны:

![DNS](src/screenshots/dns.png)

3. 
Создание ВМ с nginx и letsencrypt. Воспользуемся предварительным конфигом ВМ из предыдущего пункта диплома,
[инструкцией по установке nginx и letsencrypt](https://gist.github.com/mattiaslundberg/ba214a35060d3c8603e9b1ec8627d349) для написания собственной роли по настройке nginx reverse-proxy.

### 7.Установка кластера MySQL

При подготовке ansible роли [mysql](https://github.com/dsnikolaev13/devops-netology/tree/main/diplom/src/ansible/mysql) использовали [готовую роль](https://galaxy.ansible.com/geerlingguy/mysql)

<details><summary>Лог работы playbook ansible</summary>
2022-11-06 14:42:55,242 p=340599 u=dnikolaev n=ansible | PLAY [mysql] *************************************************************************************************************************************************************************************************************************
2022-11-06 14:42:55,254 p=340599 u=dnikolaev n=ansible | TASK [Gathering Facts] ***************************************************************************************************************************************************************************************************************
2022-11-06 14:42:58,389 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:42:58,392 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:42:58,417 p=340599 u=dnikolaev n=ansible | TASK [mysql : include_tasks] *********************************************************************************************************************************************************************************************************
2022-11-06 14:42:58,470 p=340599 u=dnikolaev n=ansible | included: /home/dnikolaev/devops-netology/diplom2/src/ansible/mysql/tasks/variables.yml for 192.168.1.16, 192.168.1.17
2022-11-06 14:42:58,486 p=340599 u=dnikolaev n=ansible | TASK [mysql : Include OS-specific variables.] ****************************************************************************************************************************************************************************************
2022-11-06 14:42:58,520 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16] => (item=/home/dnikolaev/devops-netology/diplom2/src/ansible/mysql/vars/Debian.yml)
2022-11-06 14:42:58,542 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17] => (item=/home/dnikolaev/devops-netology/diplom2/src/ansible/mysql/vars/Debian.yml)
2022-11-06 14:42:58,560 p=340599 u=dnikolaev n=ansible | TASK [mysql : Define mysql_packages.] ************************************************************************************************************************************************************************************************
2022-11-06 14:42:58,642 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:42:58,658 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:42:58,679 p=340599 u=dnikolaev n=ansible | TASK [mysql : Define mysql_daemon.] **************************************************************************************************************************************************************************************************
2022-11-06 14:42:58,713 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:42:58,732 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:42:58,745 p=340599 u=dnikolaev n=ansible | TASK [mysql : Define mysql_slow_query_log_file.] *************************************************************************************************************************************************************************************
2022-11-06 14:42:58,794 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:42:58,794 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:42:58,807 p=340599 u=dnikolaev n=ansible | TASK [mysql : Define mysql_log_error.] ***********************************************************************************************************************************************************************************************
2022-11-06 14:42:58,842 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:42:58,857 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:42:58,870 p=340599 u=dnikolaev n=ansible | TASK [mysql : Define mysql_syslog_tag.] **********************************************************************************************************************************************************************************************
2022-11-06 14:42:58,905 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:42:58,921 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:42:58,934 p=340599 u=dnikolaev n=ansible | TASK [mysql : Define mysql_pid_file.] ************************************************************************************************************************************************************************************************
2022-11-06 14:42:58,969 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:42:58,986 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:42:58,998 p=340599 u=dnikolaev n=ansible | TASK [mysql : Define mysql_config_file.] *********************************************************************************************************************************************************************************************
2022-11-06 14:42:59,033 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:42:59,049 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:42:59,063 p=340599 u=dnikolaev n=ansible | TASK [mysql : Define mysql_config_include_dir.] **************************************************************************************************************************************************************************************
2022-11-06 14:42:59,097 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:42:59,113 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:42:59,126 p=340599 u=dnikolaev n=ansible | TASK [mysql : Define mysql_socket.] **************************************************************************************************************************************************************************************************
2022-11-06 14:42:59,160 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:42:59,178 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:42:59,190 p=340599 u=dnikolaev n=ansible | TASK [mysql : Define mysql_supports_innodb_large_prefix.] ****************************************************************************************************************************************************************************
2022-11-06 14:42:59,225 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:42:59,241 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:42:59,254 p=340599 u=dnikolaev n=ansible | TASK [mysql : include_tasks] *********************************************************************************************************************************************************************************************************
2022-11-06 14:42:59,277 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.16]
2022-11-06 14:42:59,284 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.17]
2022-11-06 14:42:59,297 p=340599 u=dnikolaev n=ansible | TASK [mysql : include_tasks] *********************************************************************************************************************************************************************************************************
2022-11-06 14:42:59,358 p=340599 u=dnikolaev n=ansible | included: /home/dnikolaev/devops-netology/diplom2/src/ansible/mysql/tasks/setup-Debian.yml for 192.168.1.16, 192.168.1.17
2022-11-06 14:42:59,379 p=340599 u=dnikolaev n=ansible | TASK [mysql : Check if MySQL is already installed.] **********************************************************************************************************************************************************************************
2022-11-06 14:43:00,722 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:43:00,756 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:43:00,774 p=340599 u=dnikolaev n=ansible | TASK [mysql : Update apt cache if MySQL is not yet installed.] ***********************************************************************************************************************************************************************
2022-11-06 14:43:00,795 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.16]
2022-11-06 14:43:00,805 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.17]
2022-11-06 14:43:00,817 p=340599 u=dnikolaev n=ansible | TASK [mysql : Ensure MySQL Python libraries are installed.] **************************************************************************************************************************************************************************
2022-11-06 14:43:03,072 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:43:03,106 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:43:03,119 p=340599 u=dnikolaev n=ansible | TASK [mysql : Ensure MySQL packages are installed.] **********************************************************************************************************************************************************************************
2022-11-06 14:43:05,361 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:43:05,452 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:43:05,464 p=340599 u=dnikolaev n=ansible | TASK [mysql : Ensure MySQL is stopped after initial install.] ************************************************************************************************************************************************************************
2022-11-06 14:43:05,488 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.16]
2022-11-06 14:43:05,496 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.17]
2022-11-06 14:43:05,510 p=340599 u=dnikolaev n=ansible | TASK [mysql : Delete innodb log files created by apt package after initial install.] *************************************************************************************************************************************************
2022-11-06 14:43:05,529 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.16] => (item=ib_logfile0) 
2022-11-06 14:43:05,529 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.16] => (item=ib_logfile1) 
2022-11-06 14:43:05,548 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.17] => (item=ib_logfile0) 
2022-11-06 14:43:05,549 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.17] => (item=ib_logfile1) 
2022-11-06 14:43:05,563 p=340599 u=dnikolaev n=ansible | TASK [mysql : include_tasks] *********************************************************************************************************************************************************************************************************
2022-11-06 14:43:05,585 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.16]
2022-11-06 14:43:05,593 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.17]
2022-11-06 14:43:05,606 p=340599 u=dnikolaev n=ansible | TASK [mysql : Check if MySQL packages were installed.] *******************************************************************************************************************************************************************************
2022-11-06 14:43:05,677 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:43:05,692 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:43:05,706 p=340599 u=dnikolaev n=ansible | TASK [mysql : include_tasks] *********************************************************************************************************************************************************************************************************
2022-11-06 14:43:05,761 p=340599 u=dnikolaev n=ansible | included: /home/dnikolaev/devops-netology/diplom2/src/ansible/mysql/tasks/configure.yml for 192.168.1.16, 192.168.1.17
2022-11-06 14:43:05,785 p=340599 u=dnikolaev n=ansible | TASK [mysql : Get MySQL version.] ****************************************************************************************************************************************************************************************************
2022-11-06 14:43:07,040 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:43:07,077 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:43:07,088 p=340599 u=dnikolaev n=ansible | TASK [mysql : Copy my.cnf global MySQL configuration.] *******************************************************************************************************************************************************************************
2022-11-06 14:43:09,088 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:43:09,117 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:43:09,134 p=340599 u=dnikolaev n=ansible | TASK [mysql : Verify mysql include directory exists.] ********************************************************************************************************************************************************************************
2022-11-06 14:43:09,161 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.16]
2022-11-06 14:43:09,178 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.17]
2022-11-06 14:43:09,191 p=340599 u=dnikolaev n=ansible | TASK [mysql : Copy my.cnf override files into include directory.] ********************************************************************************************************************************************************************
2022-11-06 14:43:09,232 p=340599 u=dnikolaev n=ansible | TASK [mysql : Create slow query log file (if configured).] ***************************************************************************************************************************************************************************
2022-11-06 14:43:09,253 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.16]
2022-11-06 14:43:09,261 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.17]
2022-11-06 14:43:09,273 p=340599 u=dnikolaev n=ansible | TASK [mysql : Create datadir if it does not exist] ***********************************************************************************************************************************************************************************
2022-11-06 14:43:10,460 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:43:10,478 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:43:10,491 p=340599 u=dnikolaev n=ansible | TASK [mysql : Set ownership on slow query log file (if configured).] *****************************************************************************************************************************************************************
2022-11-06 14:43:10,513 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.16]
2022-11-06 14:43:10,520 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.17]
2022-11-06 14:43:10,533 p=340599 u=dnikolaev n=ansible | TASK [mysql : Create error log file (if configured).] ********************************************************************************************************************************************************************************
2022-11-06 14:43:10,560 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.16]
2022-11-06 14:43:10,578 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.17]
2022-11-06 14:43:10,590 p=340599 u=dnikolaev n=ansible | TASK [mysql : Set ownership on error log file (if configured).] **********************************************************************************************************************************************************************
2022-11-06 14:43:10,617 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.16]
2022-11-06 14:43:10,636 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.17]
2022-11-06 14:43:10,648 p=340599 u=dnikolaev n=ansible | TASK [mysql : Ensure MySQL is started and enabled on boot.] **************************************************************************************************************************************************************************
2022-11-06 14:43:12,337 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:43:12,392 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:43:12,404 p=340599 u=dnikolaev n=ansible | TASK [mysql : include_tasks] *********************************************************************************************************************************************************************************************************
2022-11-06 14:43:12,463 p=340599 u=dnikolaev n=ansible | included: /home/dnikolaev/devops-netology/diplom2/src/ansible/mysql/tasks/secure-installation.yml for 192.168.1.16, 192.168.1.17
2022-11-06 14:43:12,492 p=340599 u=dnikolaev n=ansible | TASK [mysql : Ensure default user is present.] ***************************************************************************************************************************************************************************************
2022-11-06 14:43:14,098 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.16]
2022-11-06 14:43:14,130 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.17]
2022-11-06 14:43:14,148 p=340599 u=dnikolaev n=ansible | TASK [mysql : Copy user-my.cnf file with password credentials.] **********************************************************************************************************************************************************************
2022-11-06 14:43:16,504 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:43:16,577 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:43:16,594 p=340599 u=dnikolaev n=ansible | TASK [mysql : Disallow root login remotely] ******************************************************************************************************************************************************************************************
2022-11-06 14:43:18,622 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17] => (item=DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1'))
2022-11-06 14:43:18,701 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16] => (item=DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1'))
2022-11-06 14:43:18,715 p=340599 u=dnikolaev n=ansible | TASK [mysql : Get list of hosts for the root user.] **********************************************************************************************************************************************************************************
2022-11-06 14:43:20,354 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:43:20,354 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:43:20,373 p=340599 u=dnikolaev n=ansible | TASK [mysql : Update MySQL root password for localhost root account (5.7.x).] ********************************************************************************************************************************************************
2022-11-06 14:43:21,787 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.17] => (item=localhost)
2022-11-06 14:43:21,916 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.16] => (item=localhost)
2022-11-06 14:43:21,934 p=340599 u=dnikolaev n=ansible | TASK [mysql : Update MySQL root password for localhost root account (< 5.7.x).] ******************************************************************************************************************************************************
2022-11-06 14:43:21,967 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.16] => (item=localhost) 
2022-11-06 14:43:21,984 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.17] => (item=localhost) 
2022-11-06 14:43:22,001 p=340599 u=dnikolaev n=ansible | TASK [mysql : Copy .my.cnf file with root password credentials.] *********************************************************************************************************************************************************************
2022-11-06 14:43:24,323 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:43:24,497 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:43:24,509 p=340599 u=dnikolaev n=ansible | TASK [mysql : Get list of hosts for the anonymous user.] *****************************************************************************************************************************************************************************
2022-11-06 14:43:25,684 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:43:25,783 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:43:25,800 p=340599 u=dnikolaev n=ansible | TASK [mysql : Remove anonymous MySQL users.] *****************************************************************************************************************************************************************************************
2022-11-06 14:43:25,855 p=340599 u=dnikolaev n=ansible | TASK [mysql : Remove MySQL test database.] *******************************************************************************************************************************************************************************************
2022-11-06 14:43:27,235 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:43:27,250 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:43:27,271 p=340599 u=dnikolaev n=ansible | TASK [mysql : include_tasks] *********************************************************************************************************************************************************************************************************
2022-11-06 14:43:27,331 p=340599 u=dnikolaev n=ansible | included: /home/dnikolaev/devops-netology/diplom2/src/ansible/mysql/tasks/databases.yml for 192.168.1.16, 192.168.1.17
2022-11-06 14:43:27,364 p=340599 u=dnikolaev n=ansible | TASK [mysql : Ensure MySQL databases are present.] ***********************************************************************************************************************************************************************************
2022-11-06 14:43:28,640 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16] => (item={'name': 'wordpress', 'collation': 'utf8_general_ci', 'encoding': 'utf8', 'replicate': 1})
2022-11-06 14:43:28,644 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17] => (item={'name': 'wordpress', 'collation': 'utf8_general_ci', 'encoding': 'utf8', 'replicate': 1})
2022-11-06 14:43:28,658 p=340599 u=dnikolaev n=ansible | TASK [mysql : include_tasks] *********************************************************************************************************************************************************************************************************
2022-11-06 14:43:28,710 p=340599 u=dnikolaev n=ansible | included: /home/dnikolaev/devops-netology/diplom2/src/ansible/mysql/tasks/users.yml for 192.168.1.16, 192.168.1.17
2022-11-06 14:43:28,746 p=340599 u=dnikolaev n=ansible | TASK [mysql : Ensure MySQL users are present.] ***************************************************************************************************************************************************************************************
2022-11-06 14:43:30,055 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.16] => (item=None)
2022-11-06 14:43:30,066 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.17] => (item=None)
2022-11-06 14:43:31,278 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17] => (item=None)
2022-11-06 14:43:31,280 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.17]
2022-11-06 14:43:31,318 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16] => (item=None)
2022-11-06 14:43:31,319 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.16]
2022-11-06 14:43:31,331 p=340599 u=dnikolaev n=ansible | TASK [mysql : include_tasks] *********************************************************************************************************************************************************************************************************
2022-11-06 14:43:31,387 p=340599 u=dnikolaev n=ansible | included: /home/dnikolaev/devops-netology/diplom2/src/ansible/mysql/tasks/replication.yml for 192.168.1.16, 192.168.1.17
2022-11-06 14:43:31,423 p=340599 u=dnikolaev n=ansible | TASK [mysql : Ensure replication user exists on master.] *****************************************************************************************************************************************************************************
2022-11-06 14:43:31,453 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.17]
2022-11-06 14:43:32,711 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.16]
2022-11-06 14:43:32,726 p=340599 u=dnikolaev n=ansible | TASK [mysql : Check slave replication status.] ***************************************************************************************************************************************************************************************
2022-11-06 14:43:32,749 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.16]
2022-11-06 14:43:34,177 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.17]
2022-11-06 14:43:34,200 p=340599 u=dnikolaev n=ansible | TASK [mysql : Check master replication status.] **************************************************************************************************************************************************************************************
2022-11-06 14:43:34,232 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.16]
2022-11-06 14:43:34,247 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.17]
2022-11-06 14:43:34,262 p=340599 u=dnikolaev n=ansible | TASK [mysql : Configure replication on the slave.] ***********************************************************************************************************************************************************************************
2022-11-06 14:43:34,285 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.16]
2022-11-06 14:43:34,299 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.17]
2022-11-06 14:43:34,312 p=340599 u=dnikolaev n=ansible | TASK [mysql : Start replication.] ****************************************************************************************************************************************************************************************************
2022-11-06 14:43:34,334 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.16]
2022-11-06 14:43:34,349 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.17]
</details>

### 8.Установка WordPress

1. [tf-файл ВМ с WordPress](./src/terraform/wordpress.tf)
2. Настроена A-запись в доменной зоне nikolaev63.ru
3. [Upstream для WordPress.](./src/ansible/nginx-proxy/templates/nginx-nikolaev63.j2)

<details><summary>Лог работы ansible</summary>
2022-11-06 14:43:34,402 p=340599 u=dnikolaev n=ansible | PLAY [wordpress] *********************************************************************************************************************************************************************************************************************
2022-11-06 14:43:34,416 p=340599 u=dnikolaev n=ansible | TASK [Gathering Facts] ***************************************************************************************************************************************************************************************************************
2022-11-06 14:43:38,438 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.15]
2022-11-06 14:43:38,463 p=340599 u=dnikolaev n=ansible | TASK [wordpress : Update apt cache] **************************************************************************************************************************************************************************************************
2022-11-06 14:43:41,423 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.15]
2022-11-06 14:43:41,441 p=340599 u=dnikolaev n=ansible | TASK [wordpress : Install prerequisites] *********************************************************************************************************************************************************************************************
2022-11-06 14:43:46,568 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.15]
2022-11-06 14:43:46,585 p=340599 u=dnikolaev n=ansible | TASK [wordpress : Install LAMP Packages] *********************************************************************************************************************************************************************************************
2022-11-06 14:43:51,079 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.15] => (item=apache2)
2022-11-06 14:43:55,659 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.15] => (item=php)
2022-11-06 14:43:59,065 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.15] => (item=php-mysql)
2022-11-06 14:44:02,943 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.15] => (item=libapache2-mod-php)
2022-11-06 14:44:02,957 p=340599 u=dnikolaev n=ansible | TASK [wordpress : Install PHP Extensions] ********************************************************************************************************************************************************************************************
2022-11-06 14:44:06,170 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.15] => (item=php-curl)
2022-11-06 14:44:09,360 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.15] => (item=php-gd)
2022-11-06 14:44:12,222 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.15] => (item=php-mbstring)
2022-11-06 14:44:16,462 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.15] => (item=php-xml)
2022-11-06 14:44:20,978 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.15] => (item=php-xmlrpc)
2022-11-06 14:44:25,595 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.15] => (item=php-soap)
2022-11-06 14:44:30,181 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.15] => (item=php-intl)
2022-11-06 14:44:34,901 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.15] => (item=php-zip)
2022-11-06 14:44:34,920 p=340599 u=dnikolaev n=ansible | TASK [wordpress : Create document root] **********************************************************************************************************************************************************************************************
2022-11-06 14:44:37,253 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.15]
2022-11-06 14:44:37,265 p=340599 u=dnikolaev n=ansible | TASK [wordpress : Set up Apache VirtualHost] *****************************************************************************************************************************************************************************************
2022-11-06 14:44:39,654 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.15]
2022-11-06 14:44:39,667 p=340599 u=dnikolaev n=ansible | TASK [wordpress : Enable rewrite module] *********************************************************************************************************************************************************************************************
2022-11-06 14:44:41,090 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.15]
2022-11-06 14:44:41,103 p=340599 u=dnikolaev n=ansible | TASK [wordpress : Enable new site] ***************************************************************************************************************************************************************************************************
2022-11-06 14:44:42,544 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.15]
2022-11-06 14:44:42,558 p=340599 u=dnikolaev n=ansible | TASK [wordpress : Disable default Apache site] ***************************************************************************************************************************************************************************************
2022-11-06 14:44:44,023 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.15]
2022-11-06 14:44:44,038 p=340599 u=dnikolaev n=ansible | TASK [wordpress : UFW - Allow HTTP on port 80] ***************************************************************************************************************************************************************************************
2022-11-06 14:44:45,742 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.15]
2022-11-06 14:44:45,758 p=340599 u=dnikolaev n=ansible | TASK [wordpress : Download and unpack latest WordPress] ******************************************************************************************************************************************************************************
2022-11-06 14:44:46,454 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.15]
2022-11-06 14:44:46,472 p=340599 u=dnikolaev n=ansible | TASK [wordpress : Set ownership] *****************************************************************************************************************************************************************************************************
2022-11-06 14:44:48,213 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.15]
2022-11-06 14:44:48,229 p=340599 u=dnikolaev n=ansible | TASK [wordpress : Set permissions for directories] ***********************************************************************************************************************************************************************************
2022-11-06 14:44:49,787 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.15]
2022-11-06 14:44:49,805 p=340599 u=dnikolaev n=ansible | TASK [wordpress : Set permissions for files] *****************************************************************************************************************************************************************************************
2022-11-06 14:44:53,845 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.15]
2022-11-06 14:44:53,857 p=340599 u=dnikolaev n=ansible | TASK [wordpress : Set up wp-config] **************************************************************************************************************************************************************************************************
2022-11-06 14:44:57,747 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.15]
</details>

### 9.Установка Gitlab CE и Gitlab Runner

Для установки gitlab и gitlab-runner использовал роли [ansible-gitlab](https://github.com/dsnikolaev13/devops-netology/tree/main/diplom/src/ansible/gitlab) и [ansible-gitlab-runner](https://github.com/dsnikolaev13/devops-netology/tree/main/diplom/src/ansible/gitlab-runner)

Результат работы
![Cloud](src/screenshots/Clouds.png)

<details><summary>Лог работы ansible</summary>
2022-11-06 14:45:08,528 p=340599 u=dnikolaev n=ansible | PLAY [gitlab] ************************************************************************************************************************************************************************************************************************
2022-11-06 14:45:08,543 p=340599 u=dnikolaev n=ansible | TASK [Gathering Facts] ***************************************************************************************************************************************************************************************************************
2022-11-06 14:45:11,577 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.13]
2022-11-06 14:45:11,601 p=340599 u=dnikolaev n=ansible | TASK [gitlab : Update apt cache.] ****************************************************************************************************************************************************************************************************
2022-11-06 14:45:17,806 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.13]
2022-11-06 14:45:17,818 p=340599 u=dnikolaev n=ansible | TASK [gitlab : Include OS-specific variables.] ***************************************************************************************************************************************************************************************
2022-11-06 14:45:17,851 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.13]
2022-11-06 14:45:17,864 p=340599 u=dnikolaev n=ansible | TASK [gitlab : Check if GitLab configuration file already exists.] *******************************************************************************************************************************************************************
2022-11-06 14:45:21,177 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.13]
2022-11-06 14:45:21,195 p=340599 u=dnikolaev n=ansible | TASK [gitlab : Check if GitLab is already installed.] ********************************************************************************************************************************************************************************
2022-11-06 14:45:22,424 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.13]
2022-11-06 14:45:22,439 p=340599 u=dnikolaev n=ansible | TASK [gitlab : Install GitLab dependencies.] *****************************************************************************************************************************************************************************************
2022-11-06 14:45:24,531 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.13]
2022-11-06 14:45:24,548 p=340599 u=dnikolaev n=ansible | TASK [gitlab : Install GitLab dependencies (Debian).] ********************************************************************************************************************************************************************************
2022-11-06 14:45:26,697 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.13]
2022-11-06 14:45:26,709 p=340599 u=dnikolaev n=ansible | TASK [gitlab : Download GitLab repository installation script.] **********************************************************************************************************************************************************************
2022-11-06 14:45:26,727 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.13]
2022-11-06 14:45:26,741 p=340599 u=dnikolaev n=ansible | TASK [gitlab : Install GitLab repository.] *******************************************************************************************************************************************************************************************
2022-11-06 14:45:26,754 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.13]
2022-11-06 14:45:26,766 p=340599 u=dnikolaev n=ansible | TASK [gitlab : Define the Gitlab package name.] **************************************************************************************************************************************************************************************
2022-11-06 14:45:26,793 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.13]
2022-11-06 14:45:26,805 p=340599 u=dnikolaev n=ansible | TASK [gitlab : Install GitLab] *******************************************************************************************************************************************************************************************************
2022-11-06 14:45:26,824 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.13]
2022-11-06 14:45:26,837 p=340599 u=dnikolaev n=ansible | TASK [gitlab : install runner token] *************************************************************************************************************************************************************************************************
2022-11-06 14:45:28,220 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.13]
2022-11-06 14:45:28,232 p=340599 u=dnikolaev n=ansible | TASK [gitlab : install root password] ************************************************************************************************************************************************************************************************
2022-11-06 14:45:29,413 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.13]
2022-11-06 14:45:29,426 p=340599 u=dnikolaev n=ansible | TASK [gitlab : Reconfigure GitLab (first run).] **************************************************************************************************************************************************************************************
2022-11-06 14:45:30,583 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.13]
2022-11-06 14:45:30,596 p=340599 u=dnikolaev n=ansible | TASK [gitlab : Create GitLab SSL configuration folder.] ******************************************************************************************************************************************************************************
2022-11-06 14:45:30,609 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.13]
2022-11-06 14:45:30,621 p=340599 u=dnikolaev n=ansible | TASK [gitlab : Create self-signed certificate.] **************************************************************************************************************************************************************************************
2022-11-06 14:45:30,637 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.13]
2022-11-06 14:45:30,651 p=340599 u=dnikolaev n=ansible | TASK [gitlab : Copy GitLab configuration file.] **************************************************************************************************************************************************************************************
2022-11-06 14:45:33,166 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.13]
2022-11-06 14:45:33,190 p=340599 u=dnikolaev n=ansible | TASK [node-exporter : Create User nodeexporter] **************************************************************************************************************************************************************************************
2022-11-06 14:45:34,437 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.13]
2022-11-06 14:45:34,458 p=340599 u=dnikolaev n=ansible | TASK [node-exporter : Create directories for node-exporter] **************************************************************************************************************************************************************************
2022-11-06 14:45:35,654 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.13]
2022-11-06 14:45:35,666 p=340599 u=dnikolaev n=ansible | TASK [node-exporter : Download And Unzipped node-exporter] ***************************************************************************************************************************************************************************
2022-11-06 14:45:36,238 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.13]
2022-11-06 14:45:36,255 p=340599 u=dnikolaev n=ansible | TASK [node-exporter : Copy Bin Files From Unzipped to node-exporter] *****************************************************************************************************************************************************************
2022-11-06 14:45:37,798 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.13]
2022-11-06 14:45:37,810 p=340599 u=dnikolaev n=ansible | TASK [node-exporter : Create File for node-exporter Systemd] *************************************************************************************************************************************************************************
2022-11-06 14:45:39,911 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.13]
2022-11-06 14:45:39,926 p=340599 u=dnikolaev n=ansible | TASK [node-exporter : Systemctl node-exporter Start] *********************************************************************************************************************************************************************************
2022-11-06 14:45:41,299 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.13]
2022-11-06 14:45:41,325 p=340599 u=dnikolaev n=ansible | RUNNING HANDLER [gitlab : restart gitlab] ********************************************************************************************************************************************************************************************
2022-11-06 14:45:55,103 p=340599 u=dnikolaev n=ansible | changed: [192.168.1.13]
2022-11-06 14:45:55,120 p=340599 u=dnikolaev n=ansible | PLAY [runner] ************************************************************************************************************************************************************************************************************************
2022-11-06 14:45:55,224 p=340599 u=dnikolaev n=ansible | TASK [Gathering Facts] ***************************************************************************************************************************************************************************************************************
2022-11-06 14:46:00,927 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:00,953 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Load platform-specific variables] ******************************************************************************************************************************************************************************
2022-11-06 14:46:00,998 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:01,015 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Container) Pull Image from Registry] **************************************************************************************************************************************************************************
2022-11-06 14:46:01,030 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,042 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Container) Define Container volume Path] **********************************************************************************************************************************************************************
2022-11-06 14:46:01,056 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,068 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Container) List configured runners] ***************************************************************************************************************************************************************************
2022-11-06 14:46:01,081 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,094 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Container) Check runner is registered] ************************************************************************************************************************************************************************
2022-11-06 14:46:01,107 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,121 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : configured_runners?] *******************************************************************************************************************************************************************************************
2022-11-06 14:46:01,134 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,146 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : verified_runners?] *********************************************************************************************************************************************************************************************
2022-11-06 14:46:01,159 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,172 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Container) Register GitLab Runner] ****************************************************************************************************************************************************************************
2022-11-06 14:46:01,191 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18] => (item={'name': 'runner', 'state': 'present', 'executor': 'shell', 'output_limit': 4096, 'concurrent_specific': '0', 'docker_image': '', 'tags': [], 'run_untagged': True, 'protected': False, 'docker_privileged': False, 'locked': 'false', 'docker_network_mode': 'bridge', 'env_vars': []}) 
2022-11-06 14:46:01,205 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Create .gitlab-runner dir] *************************************************************************************************************************************************************************************
2022-11-06 14:46:01,217 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,231 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Ensure config.toml exists] *************************************************************************************************************************************************************************************
2022-11-06 14:46:01,245 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,258 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Set concurrent option] *****************************************************************************************************************************************************************************************
2022-11-06 14:46:01,278 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,291 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Add listen_address to config] **********************************************************************************************************************************************************************************
2022-11-06 14:46:01,305 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,318 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Add log_format to config] **************************************************************************************************************************************************************************************
2022-11-06 14:46:01,331 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,345 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Add sentry dsn to config] **************************************************************************************************************************************************************************************
2022-11-06 14:46:01,358 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,372 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Add session server listen_address to config] *******************************************************************************************************************************************************************
2022-11-06 14:46:01,384 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,397 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Add session server advertise_address to config] ****************************************************************************************************************************************************************
2022-11-06 14:46:01,411 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,424 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Add session server session_timeout to config] ******************************************************************************************************************************************************************
2022-11-06 14:46:01,438 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,451 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Get existing config.toml] **************************************************************************************************************************************************************************************
2022-11-06 14:46:01,463 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,476 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Get pre-existing runner configs] *******************************************************************************************************************************************************************************
2022-11-06 14:46:01,489 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,503 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Create temporary directory] ************************************************************************************************************************************************************************************
2022-11-06 14:46:01,515 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,528 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Write config section for each runner] **************************************************************************************************************************************************************************
2022-11-06 14:46:01,543 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,556 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Assemble new config.toml] **************************************************************************************************************************************************************************************
2022-11-06 14:46:01,570 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,583 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Container) Start the container] *******************************************************************************************************************************************************************************
2022-11-06 14:46:01,601 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:01,613 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Debian) Get Gitlab repository installation script] ************************************************************************************************************************************************************
2022-11-06 14:46:03,355 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:03,376 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Debian) Install Gitlab repository] ****************************************************************************************************************************************************************************
2022-11-06 14:46:04,566 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:04,581 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Debian) Update gitlab_runner_package_name] ********************************************************************************************************************************************************************
2022-11-06 14:46:04,603 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:04,615 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Debian) Set gitlab_runner_package_name] ***********************************************************************************************************************************************************************
2022-11-06 14:46:04,655 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:04,668 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Debian) Install GitLab Runner] ********************************************************************************************************************************************************************************
2022-11-06 14:46:06,753 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:06,766 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Debian) Install GitLab Runner] ********************************************************************************************************************************************************************************
2022-11-06 14:46:06,785 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:06,805 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Debian) Remove ~/gitlab-runner/.bash_logout on debian buster and ubuntu focal] ********************************************************************************************************************************
2022-11-06 14:46:08,007 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:08,022 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Ensure /etc/systemd/system/gitlab-runner.service.d/ exists] ****************************************************************************************************************************************************
2022-11-06 14:46:09,276 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:09,293 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Add reload command to GitLab Runner system service] ************************************************************************************************************************************************************
2022-11-06 14:46:11,322 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:11,334 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Configure graceful stop for GitLab Runner system service] ******************************************************************************************************************************************************
2022-11-06 14:46:13,410 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:13,428 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Force systemd to reread configs] *******************************************************************************************************************************************************************************
2022-11-06 14:46:15,423 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:15,441 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (RedHat) Get Gitlab repository installation script] ************************************************************************************************************************************************************
2022-11-06 14:46:15,459 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:15,472 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (RedHat) Install Gitlab repository] ****************************************************************************************************************************************************************************
2022-11-06 14:46:15,487 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:15,507 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (RedHat) Update gitlab_runner_package_name] ********************************************************************************************************************************************************************
2022-11-06 14:46:15,524 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:15,537 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (RedHat) Set gitlab_runner_package_name] ***********************************************************************************************************************************************************************
2022-11-06 14:46:15,553 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:15,566 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (RedHat) Install GitLab Runner] ********************************************************************************************************************************************************************************
2022-11-06 14:46:15,581 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:15,595 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Ensure /etc/systemd/system/gitlab-runner.service.d/ exists] ****************************************************************************************************************************************************
2022-11-06 14:46:15,612 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:15,624 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Add reload command to GitLab Runner system service] ************************************************************************************************************************************************************
2022-11-06 14:46:15,639 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:15,653 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Configure graceful stop for GitLab Runner system service] ******************************************************************************************************************************************************
2022-11-06 14:46:15,669 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:15,683 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Force systemd to reread configs] *******************************************************************************************************************************************************************************
2022-11-06 14:46:15,704 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:15,716 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (MacOS) Check gitlab-runner executable exists] *****************************************************************************************************************************************************************
2022-11-06 14:46:15,734 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:15,747 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (MacOS) Set fact -> gitlab_runner_exists] **********************************************************************************************************************************************************************
2022-11-06 14:46:15,765 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:15,778 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (MacOS) Get existing version] **********************************************************************************************************************************************************************************
2022-11-06 14:46:15,795 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:15,808 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (MacOS) Set fact -> gitlab_runner_existing_version] ************************************************************************************************************************************************************
2022-11-06 14:46:15,825 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:15,839 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (MacOS) Precreate gitlab-runner log directory] *****************************************************************************************************************************************************************
2022-11-06 14:46:15,854 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:15,867 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (MacOS) Download GitLab Runner] ********************************************************************************************************************************************************************************
2022-11-06 14:46:15,882 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:15,896 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (MacOS) Setting Permissions for gitlab-runner executable] ******************************************************************************************************************************************************
2022-11-06 14:46:15,912 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:15,925 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (MacOS) Install GitLab Runner] *********************************************************************************************************************************************************************************
2022-11-06 14:46:15,941 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:15,953 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (MacOS) Start GitLab Runner] ***********************************************************************************************************************************************************************************
2022-11-06 14:46:15,969 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:15,983 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (MacOS) Stop GitLab Runner] ************************************************************************************************************************************************************************************
2022-11-06 14:46:16,000 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:16,013 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (MacOS) Download GitLab Runner] ********************************************************************************************************************************************************************************
2022-11-06 14:46:16,028 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:16,042 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (MacOS) Setting Permissions for gitlab-runner executable] ******************************************************************************************************************************************************
2022-11-06 14:46:16,061 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:16,073 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (MacOS) Start GitLab Runner] ***********************************************************************************************************************************************************************************
2022-11-06 14:46:16,088 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:16,102 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Arch) Set gitlab_runner_package_name] *************************************************************************************************************************************************************************
2022-11-06 14:46:16,120 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:16,133 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Arch) Install GitLab Runner] **********************************************************************************************************************************************************************************
2022-11-06 14:46:16,154 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:16,169 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Ensure /etc/systemd/system/gitlab-runner.service.d/ exists] ****************************************************************************************************************************************************
2022-11-06 14:46:16,185 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:16,198 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Add reload command to GitLab Runner system service] ************************************************************************************************************************************************************
2022-11-06 14:46:16,214 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:16,227 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Configure graceful stop for GitLab Runner system service] ******************************************************************************************************************************************************
2022-11-06 14:46:16,249 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:16,261 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Force systemd to reread configs] *******************************************************************************************************************************************************************************
2022-11-06 14:46:16,283 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:16,298 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Unix) List configured runners] ********************************************************************************************************************************************************************************
2022-11-06 14:46:19,184 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:19,200 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Unix) Check runner is registered] *****************************************************************************************************************************************************************************
2022-11-06 14:46:20,586 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:20,600 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Unix) Register GitLab Runner] *********************************************************************************************************************************************************************************
2022-11-06 14:46:20,655 p=340599 u=dnikolaev n=ansible | included: /home/dnikolaev/devops-netology/diplom2/src/ansible/gitlab-runner/tasks/register-runner.yml for 192.168.1.18 => (item={'name': 'runner', 'state': 'present', 'executor': 'shell', 'output_limit': 4096, 'concurrent_specific': '0', 'docker_image': '', 'tags': [], 'run_untagged': True, 'protected': False, 'docker_privileged': False, 'locked': 'false', 'docker_network_mode': 'bridge', 'env_vars': []})
2022-11-06 14:46:20,693 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : remove config.toml file] ***************************************************************************************************************************************************************************************
2022-11-06 14:46:20,713 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:20,730 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Create .gitlab-runner dir] *************************************************************************************************************************************************************************************
2022-11-06 14:46:20,746 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:20,760 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Ensure config.toml exists] *************************************************************************************************************************************************************************************
2022-11-06 14:46:20,782 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:20,796 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Construct the runner command without secrets] ******************************************************************************************************************************************************************
2022-11-06 14:46:20,875 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:20,887 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Register runner to GitLab] *************************************************************************************************************************************************************************************
2022-11-06 14:46:20,921 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:20,935 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Create .gitlab-runner dir] *************************************************************************************************************************************************************************************
2022-11-06 14:46:22,177 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:22,190 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Ensure config.toml exists] *************************************************************************************************************************************************************************************
2022-11-06 14:46:23,356 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:23,372 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Set concurrent option] *****************************************************************************************************************************************************************************************
2022-11-06 14:46:24,506 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:24,524 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Add listen_address to config] **********************************************************************************************************************************************************************************
2022-11-06 14:46:24,554 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:24,567 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Add log_format to config] **************************************************************************************************************************************************************************************
2022-11-06 14:46:25,674 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:25,688 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Add sentry dsn to config] **************************************************************************************************************************************************************************************
2022-11-06 14:46:25,718 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:25,731 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Add session server listen_address to config] *******************************************************************************************************************************************************************
2022-11-06 14:46:26,859 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:26,876 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Add session server advertise_address to config] ****************************************************************************************************************************************************************
2022-11-06 14:46:28,006 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:28,019 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Add session server session_timeout to config] ******************************************************************************************************************************************************************
2022-11-06 14:46:29,122 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:29,138 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Get existing config.toml] **************************************************************************************************************************************************************************************
2022-11-06 14:46:30,350 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:30,363 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Get pre-existing runner configs] *******************************************************************************************************************************************************************************
2022-11-06 14:46:30,449 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:30,467 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Create temporary directory] ************************************************************************************************************************************************************************************
2022-11-06 14:46:31,807 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:31,822 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Write config section for each runner] **************************************************************************************************************************************************************************
2022-11-06 14:46:31,863 p=340599 u=dnikolaev n=ansible | included: /home/dnikolaev/devops-netology/diplom2/src/ansible/gitlab-runner/tasks/config-runner.yml for 192.168.1.18 => (item=log_format = "runner"
concurrent = 4
check_interval = 0

[session_server]
  session_timeout = 1800

)
2022-11-06 14:46:31,867 p=340599 u=dnikolaev n=ansible | included: /home/dnikolaev/devops-netology/diplom2/src/ansible/gitlab-runner/tasks/config-runner.yml for 192.168.1.18 => (item=  name = "runner"
  limit = 0
  output_limit = 4096
  url = "http://gitlab.nikolaev63.ru"
  environment = []
  id = 1
  token = "********************"
  token_obtained_at = 2022-11-06T10:38:34Z
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "shell"
  [runners.cache]
    image = ""
    privileged = false
    network_mode = "bridge"
)
2022-11-06 14:46:31,898 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[1/2]: Create temporary file] ******************************************************************************************************************************************************************************
2022-11-06 14:46:32,957 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:32,974 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[1/2]: Isolate runner configuration] ***********************************************************************************************************************************************************************
2022-11-06 14:46:35,034 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:35,047 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : include_tasks] *************************************************************************************************************************************************************************************************
2022-11-06 14:46:35,075 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18] => (item={'name': 'runner', 'state': 'present', 'executor': 'shell', 'output_limit': 4096, 'concurrent_specific': '0', 'docker_image': '', 'tags': [], 'run_untagged': True, 'protected': False, 'docker_privileged': False, 'locked': 'false', 'docker_network_mode': 'bridge', 'env_vars': []}) 
2022-11-06 14:46:35,094 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[1/2]: Remove runner config] *******************************************************************************************************************************************************************************
2022-11-06 14:46:35,117 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18] => (item={'name': 'runner', 'state': 'present', 'executor': 'shell', 'output_limit': 4096, 'concurrent_specific': '0', 'docker_image': '', 'tags': [], 'run_untagged': True, 'protected': False, 'docker_privileged': False, 'locked': 'false', 'docker_network_mode': 'bridge', 'env_vars': []}) 
2022-11-06 14:46:35,135 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: Create temporary file] ******************************************************************************************************************************************************************************
2022-11-06 14:46:36,167 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:36,183 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: Isolate runner configuration] ***********************************************************************************************************************************************************************
2022-11-06 14:46:38,306 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:38,326 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : include_tasks] *************************************************************************************************************************************************************************************************
2022-11-06 14:46:38,413 p=340599 u=dnikolaev n=ansible | included: /home/dnikolaev/devops-netology/diplom2/src/ansible/gitlab-runner/tasks/update-config-runner.yml for 192.168.1.18 => (item={'name': 'runner', 'state': 'present', 'executor': 'shell', 'output_limit': 4096, 'concurrent_specific': '0', 'docker_image': '', 'tags': [], 'run_untagged': True, 'protected': False, 'docker_privileged': False, 'locked': 'false', 'docker_network_mode': 'bridge', 'env_vars': []})
2022-11-06 14:46:38,444 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set concurrent limit option] ***********************************************************************************************************************************************************
2022-11-06 14:46:39,516 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:39,536 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set coordinator URL] *******************************************************************************************************************************************************************
2022-11-06 14:46:40,638 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:40,657 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set clone URL] *************************************************************************************************************************************************************************
2022-11-06 14:46:40,679 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:40,701 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set environment option] ****************************************************************************************************************************************************************
2022-11-06 14:46:41,762 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:41,781 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set pre_clone_script] ******************************************************************************************************************************************************************
2022-11-06 14:46:41,806 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:41,826 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set pre_build_script] ******************************************************************************************************************************************************************
2022-11-06 14:46:41,855 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:41,875 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set tls_ca_file] ***********************************************************************************************************************************************************************
2022-11-06 14:46:41,896 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:41,916 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set post_build_script] *****************************************************************************************************************************************************************
2022-11-06 14:46:41,938 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:46:41,958 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set runner executor option] ************************************************************************************************************************************************************
2022-11-06 14:46:43,012 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:43,032 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set runner shell option] ***************************************************************************************************************************************************************
2022-11-06 14:46:44,133 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:44,157 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set runner executor section] ***********************************************************************************************************************************************************
2022-11-06 14:46:45,222 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:45,242 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set output_limit option] ***************************************************************************************************************************************************************
2022-11-06 14:46:46,298 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:46,327 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set runner docker image option] ********************************************************************************************************************************************************
2022-11-06 14:46:47,412 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:47,431 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set docker helper image option] ********************************************************************************************************************************************************
2022-11-06 14:46:48,502 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:48,526 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set docker privileged option] **********************************************************************************************************************************************************
2022-11-06 14:46:49,575 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:49,595 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set docker wait_for_services_timeout option] *******************************************************************************************************************************************
2022-11-06 14:46:50,684 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:50,703 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set docker tlsverify option] ***********************************************************************************************************************************************************
2022-11-06 14:46:51,798 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:51,818 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set docker shm_size option] ************************************************************************************************************************************************************
2022-11-06 14:46:52,872 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:52,893 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set docker disable_cache option] *******************************************************************************************************************************************************
2022-11-06 14:46:53,962 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:53,985 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set docker DNS option] *****************************************************************************************************************************************************************
2022-11-06 14:46:55,036 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:55,065 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set docker DNS search option] **********************************************************************************************************************************************************
2022-11-06 14:46:56,115 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:56,134 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set docker pull_policy option] *********************************************************************************************************************************************************
2022-11-06 14:46:57,255 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:57,275 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set docker volumes option] *************************************************************************************************************************************************************
2022-11-06 14:46:58,351 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:58,375 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set docker devices option] *************************************************************************************************************************************************************
2022-11-06 14:46:59,429 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:46:59,458 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set runner docker network option] ******************************************************************************************************************************************************
2022-11-06 14:47:00,875 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:00,893 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set custom_build_dir section] **********************************************************************************************************************************************************
2022-11-06 14:47:01,971 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:02,001 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set docker custom_build_dir-enabled option] ********************************************************************************************************************************************
2022-11-06 14:47:03,142 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:03,172 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache section] *********************************************************************************************************************************************************************
2022-11-06 14:47:04,294 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:04,314 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache s3 section] ******************************************************************************************************************************************************************
2022-11-06 14:47:05,449 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:05,468 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache gcs section] *****************************************************************************************************************************************************************
2022-11-06 14:47:06,590 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:06,611 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache azure section] ***************************************************************************************************************************************************************
2022-11-06 14:47:07,764 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:07,788 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache type option] *****************************************************************************************************************************************************************
2022-11-06 14:47:09,409 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:09,429 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache path option] *****************************************************************************************************************************************************************
2022-11-06 14:47:10,675 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:10,695 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache shared option] ***************************************************************************************************************************************************************
2022-11-06 14:47:11,839 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:11,858 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache s3 server addresss] **********************************************************************************************************************************************************
2022-11-06 14:47:13,189 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:13,209 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache s3 access key] ***************************************************************************************************************************************************************
2022-11-06 14:47:14,420 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:14,441 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache s3 secret key] ***************************************************************************************************************************************************************
2022-11-06 14:47:15,615 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:15,635 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache s3 bucket name option] *******************************************************************************************************************************************************
2022-11-06 14:47:15,655 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:15,679 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache s3 bucket location option] ***************************************************************************************************************************************************
2022-11-06 14:47:16,784 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:16,804 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache s3 insecure option] **********************************************************************************************************************************************************
2022-11-06 14:47:17,872 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:17,890 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache gcs bucket name] *************************************************************************************************************************************************************
2022-11-06 14:47:17,919 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:17,938 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache gcs credentials file] ********************************************************************************************************************************************************
2022-11-06 14:47:19,065 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:19,095 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache gcs access id] ***************************************************************************************************************************************************************
2022-11-06 14:47:20,155 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:20,175 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache gcs private key] *************************************************************************************************************************************************************
2022-11-06 14:47:21,251 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:21,276 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache azure account name] **********************************************************************************************************************************************************
2022-11-06 14:47:22,428 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:22,451 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache azure account key] ***********************************************************************************************************************************************************
2022-11-06 14:47:23,592 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:23,611 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache azure container name] ********************************************************************************************************************************************************
2022-11-06 14:47:24,672 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:24,692 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache azure storage domain] ********************************************************************************************************************************************************
2022-11-06 14:47:25,769 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:25,789 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set ssh user option] *******************************************************************************************************************************************************************
2022-11-06 14:47:26,854 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:26,874 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set ssh host option] *******************************************************************************************************************************************************************
2022-11-06 14:47:27,936 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:27,955 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set ssh port option] *******************************************************************************************************************************************************************
2022-11-06 14:47:29,046 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:29,067 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set ssh password option] ***************************************************************************************************************************************************************
2022-11-06 14:47:30,228 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:30,251 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set ssh identity file option] **********************************************************************************************************************************************************
2022-11-06 14:47:31,312 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:31,332 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set virtualbox base name option] *******************************************************************************************************************************************************
2022-11-06 14:47:31,356 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:31,377 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set virtualbox base snapshot option] ***************************************************************************************************************************************************
2022-11-06 14:47:31,398 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:31,418 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set virtualbox base folder option] *****************************************************************************************************************************************************
2022-11-06 14:47:31,446 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:31,466 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set virtualbox disable snapshots option] ***********************************************************************************************************************************************
2022-11-06 14:47:31,490 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:31,509 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set builds dir file option] ************************************************************************************************************************************************************
2022-11-06 14:47:32,556 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:32,580 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Set cache dir file option] *************************************************************************************************************************************************************
2022-11-06 14:47:33,662 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:33,687 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Ensure directory permissions] **********************************************************************************************************************************************************
2022-11-06 14:47:33,717 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18] => (item=) 
2022-11-06 14:47:33,718 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18] => (item=) 
2022-11-06 14:47:33,738 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Ensure directory access test] **********************************************************************************************************************************************************
2022-11-06 14:47:33,763 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18] => (item=) 
2022-11-06 14:47:33,768 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18] => (item=) 
2022-11-06 14:47:33,789 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: runner[1/1]: Ensure directory access fail on error] *************************************************************************************************************************************************
2022-11-06 14:47:33,817 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18] => (item={'changed': False, 'skipped': True, 'skip_reason': 'Conditional result was False', 'item': '', 'ansible_loop_var': 'item'}) 
2022-11-06 14:47:33,819 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18] => (item={'changed': False, 'skipped': True, 'skip_reason': 'Conditional result was False', 'item': '', 'ansible_loop_var': 'item'}) 
2022-11-06 14:47:33,834 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : include_tasks] *************************************************************************************************************************************************************************************************
2022-11-06 14:47:33,857 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:33,875 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : conf[2/2]: Remove runner config] *******************************************************************************************************************************************************************************
2022-11-06 14:47:33,900 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18] => (item={'name': 'runner', 'state': 'present', 'executor': 'shell', 'output_limit': 4096, 'concurrent_specific': '0', 'docker_image': '', 'tags': [], 'run_untagged': True, 'protected': False, 'docker_privileged': False, 'locked': 'false', 'docker_network_mode': 'bridge', 'env_vars': []}) 
2022-11-06 14:47:33,914 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : Assemble new config.toml] **************************************************************************************************************************************************************************************
2022-11-06 14:47:35,207 p=340599 u=dnikolaev n=ansible | ok: [192.168.1.18]
2022-11-06 14:47:35,220 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Check gitlab-runner executable exists] ***************************************************************************************************************************************************************
2022-11-06 14:47:35,234 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,248 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Set fact -> gitlab_runner_exists] ********************************************************************************************************************************************************************
2022-11-06 14:47:35,262 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,275 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Get existing version] ********************************************************************************************************************************************************************************
2022-11-06 14:47:35,289 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,304 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Set fact -> gitlab_runner_existing_version] **********************************************************************************************************************************************************
2022-11-06 14:47:35,317 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,331 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Ensure install directory exists] *********************************************************************************************************************************************************************
2022-11-06 14:47:35,348 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,361 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Download GitLab Runner] ******************************************************************************************************************************************************************************
2022-11-06 14:47:35,375 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,389 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Install GitLab Runner] *******************************************************************************************************************************************************************************
2022-11-06 14:47:35,403 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,417 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Install GitLab Runner] *******************************************************************************************************************************************************************************
2022-11-06 14:47:35,433 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,446 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Make sure runner is stopped] *************************************************************************************************************************************************************************
2022-11-06 14:47:35,461 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,473 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Download GitLab Runner] ******************************************************************************************************************************************************************************
2022-11-06 14:47:35,488 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,507 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) List configured runners] *****************************************************************************************************************************************************************************
2022-11-06 14:47:35,520 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,534 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Check runner is registered] **************************************************************************************************************************************************************************
2022-11-06 14:47:35,548 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,562 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Register GitLab Runner] ******************************************************************************************************************************************************************************
2022-11-06 14:47:35,580 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18] => (item={'name': 'runner', 'state': 'present', 'executor': 'shell', 'output_limit': 4096, 'concurrent_specific': '0', 'docker_image': '', 'tags': [], 'run_untagged': True, 'protected': False, 'docker_privileged': False, 'locked': 'false', 'docker_network_mode': 'bridge', 'env_vars': []}) 
2022-11-06 14:47:35,594 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Create .gitlab-runner dir] ***************************************************************************************************************************************************************************
2022-11-06 14:47:35,611 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,627 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Ensure config.toml exists] ***************************************************************************************************************************************************************************
2022-11-06 14:47:35,642 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,655 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Set concurrent option] *******************************************************************************************************************************************************************************
2022-11-06 14:47:35,670 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,684 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Add listen_address to config] ************************************************************************************************************************************************************************
2022-11-06 14:47:35,698 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,710 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Add sentry dsn to config] ****************************************************************************************************************************************************************************
2022-11-06 14:47:35,724 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,738 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Add session server listen_address to config] *********************************************************************************************************************************************************
2022-11-06 14:47:35,752 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,765 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Add session server advertise_address to config] ******************************************************************************************************************************************************
2022-11-06 14:47:35,783 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,796 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Add session server session_timeout to config] ********************************************************************************************************************************************************
2022-11-06 14:47:35,811 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,824 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Get existing config.toml] ****************************************************************************************************************************************************************************
2022-11-06 14:47:35,838 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,851 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Get pre-existing global config] **********************************************************************************************************************************************************************
2022-11-06 14:47:35,866 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,879 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Get pre-existing runner configs] *********************************************************************************************************************************************************************
2022-11-06 14:47:35,893 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,906 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Create temporary directory] **************************************************************************************************************************************************************************
2022-11-06 14:47:35,921 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:35,934 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Write config section for each runner] ****************************************************************************************************************************************************************
2022-11-06 14:47:35,957 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18] => (item=log_format = "runner"
concurrent = 4
check_interval = 0

[session_server]
  session_timeout = 1800

) 
2022-11-06 14:47:35,958 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18] => (item=  name = "runner"
  limit = 0
  output_limit = 4096
  url = "http://gitlab.nikolaev63.ru"
  environment = []
  id = 1
  token = "********************"
  token_obtained_at = 2022-11-06T10:38:34Z
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "shell"
  [runners.cache]
    image = ""
    privileged = false
    network_mode = "bridge"
) 
2022-11-06 14:47:35,971 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Create temporary file config.toml] *******************************************************************************************************************************************************************
2022-11-06 14:47:35,988 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:36,003 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Write global config to file] *************************************************************************************************************************************************************************
2022-11-06 14:47:36,018 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:36,031 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Create temporary file runners-config.toml] ***********************************************************************************************************************************************************
2022-11-06 14:47:36,046 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:36,060 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Assemble runners files in config dir] ****************************************************************************************************************************************************************
2022-11-06 14:47:36,074 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:36,087 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Assemble new config.toml] ****************************************************************************************************************************************************************************
2022-11-06 14:47:36,102 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:36,116 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Verify config] ***************************************************************************************************************************************************************************************
2022-11-06 14:47:36,131 p=340599 u=dnikolaev n=ansible | skipping: [192.168.1.18]
2022-11-06 14:47:36,144 p=340599 u=dnikolaev n=ansible | TASK [gitlab-runner : (Windows) Start GitLab Runner]
</details>

### 10.Установка Prometheus, Alert Manager, Node Exporter и Grafana

Добавлен [terraform манифест](./src/terraform/monitoring.tf) для ВМ monitoring.nikolaev63.ru

Роли:
* [grafana](./src/ansible/grafana)
* [prometheus](./src/ansible/prometheus)
* [alertmanager](./src/ansible/alertmanager)
* [node-exporter](./src/ansible/node-exporter)

Результаты работы.
![monitor](src/screenshots/monitor.png)

Лог работы ansible https://github.com/dsnikolaev13/devops-netology/blob/5b5de4c6e251f3cdb5408e7b1d9b856e9c5d3bc2/diplom/src/ansible/ansible.log

