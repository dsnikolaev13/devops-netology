# Домашнее задание к занятию "3.5. Файловые системы"

1. Узнайте о [sparse](https://ru.wikipedia.org/wiki/%D0%A0%D0%B0%D0%B7%D1%80%D0%B5%D0%B6%D1%91%D0%BD%D0%BD%D1%8B%D0%B9_%D1%84%D0%B0%D0%B9%D0%BB) (разряженных) файлах.

    **Ответ:**  
Это файлы, в которых последовательности нулевых байтов заменены на информацию об этих последовательностях (список дыр). Моя файловая система ext4 поддерживает sparse файлы, значит я могу использоватеь их как резервные копии или архив, например, фотографий (cp --sparse=always ./foto.jpg ./sparse-foto.jpg). Кроме этого, можно использовать sparse для образов виртуальных машин.  

1. Могут ли файлы, являющиеся жесткой ссылкой на один объект, иметь разные права доступа и владельца? Почему?

    **Ответ:**  
Жесткая ссылка и файл, для которой она создавалась имеют одинаковые inode. Поэтому жесткая ссылка имеет те же права доступа, владельца и время последней модификации, что и целевой файл. Различаются только имена файлов. Фактически жесткая ссылка это еще одно имя для файла.  


1. Сделайте `vagrant destroy` на имеющийся инстанс Ubuntu. Замените содержимое Vagrantfile следующим:

    ```bash
    Vagrant.configure("2") do |config|
      config.vm.box = "bento/ubuntu-20.04"
      config.vm.provider :virtualbox do |vb|
        lvm_experiments_disk0_path = "/tmp/lvm_experiments_disk0.vmdk"
        lvm_experiments_disk1_path = "/tmp/lvm_experiments_disk1.vmdk"
        vb.customize ['createmedium', '--filename', lvm_experiments_disk0_path, '--size', 2560]
        vb.customize ['createmedium', '--filename', lvm_experiments_disk1_path, '--size', 2560]
        vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 1, '--device', 0, '--type',         'hdd', '--medium', lvm_experiments_disk0_path]
        vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 2, '--device', 0, '--type',     'hdd', '--medium', lvm_experiments_disk1_path]
      end
    end
    ```

    Данная конфигурация создаст новую виртуальную машину с двумя дополнительными неразмеченными дисками по 2.5 Гб.

    **Ответ:**  

    ```bash
    vagrant@vagrant:~$ lsblk
    NAME                 MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
    sda                    8:0    0   64G  0 disk 
    ├─sda1                 8:1    0  512M  0 part /boot/efi
    ├─sda2                 8:2    0    1K  0 part 
    └─sda5                 8:5    0 63.5G  0 part 
      ├─vgvagrant-root   253:0    0 62.6G  0 lvm  /
      └─vgvagrant-swap_1 253:1    0  980M  0 lvm  [SWAP]
    sdb                    8:16   0  2.5G  0 disk 
    sdc                    8:32   0  2.5G  0 disk 
    ```

1. Используя `fdisk`, разбейте первый диск на 2 раздела: 2 Гб, оставшееся пространство.

    **Ответ:**  

    ```bash
    Device     Boot   Start     End Sectors  Size Id Type
    /dev/sdb1          2048 4196351 4194304    2G 83 Linux
    /dev/sdb2       4196352 5242879 1046528  511M 83 Linux
    
    Command (m for help): w
    The partition table has been altered.
    Calling ioctl() to re-read partition table.
    Syncing disks.
    
    root@vagrant:~# lsblk
    NAME                 MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
    sda                    8:0    0   64G  0 disk 
    ├─sda1                 8:1    0  512M  0 part /boot/efi
    ├─sda2                 8:2    0    1K  0 part 
    └─sda5                 8:5    0 63.5G  0 part 
      ├─vgvagrant-root   253:0    0 62.6G  0 lvm  /
      └─vgvagrant-swap_1 253:1    0  980M  0 lvm  [SWAP]
    sdb                    8:16   0  2.5G  0 disk 
    ├─sdb1                 8:17   0    2G  0 part 
    └─sdb2                 8:18   0  511M  0 part 
    sdc                    8:32   0  2.5G  0 disk 
    ```

1. Используя `sfdisk`, перенесите данную таблицу разделов на второй диск.

    **Ответ:**  

    ```bash
    root@vagrant:~# sfdisk -d /dev/sdb|sfdisk /dev/sdc
    Checking that no-one is using this disk right now ... OK
    
    Disk /dev/sdc: 2.51 GiB, 2684354560 bytes, 5242880 sectors
    Disk model: VBOX HARDDISK   
    Units: sectors of 1 * 512 = 512 bytes
    Sector size (logical/physical): 512 bytes / 512 bytes
    I/O size (minimum/optimal): 512 bytes / 512 bytes
    
    >>> Script header accepted.
    >>> Script header accepted.
    >>> Script header accepted.
    >>> Script header accepted.
    >>> Created a new DOS disklabel with disk identifier 0x64aa5f59.
    /dev/sdc1: Created a new partition 1 of type 'Linux' and of size 2 GiB.
    /dev/sdc2: Created a new partition 2 of type 'Linux' and of size 511 MiB.
    /dev/sdc3: Done.
    
    New situation:
    Disklabel type: dos
    Disk identifier: 0x64aa5f59
    
    Device     Boot   Start     End Sectors  Size Id Type
    /dev/sdc1          2048 4196351 4194304    2G 83 Linux
    /dev/sdc2       4196352 5242879 1046528  511M 83 Linux
    
    The partition table has been altered.
    Calling ioctl() to re-read partition table.
    Syncing disks. 
    Disk /dev/sdb: 2.51 GiB, 2684354560 bytes, 5242880 sectors
    Disk model: VBOX HARDDISK   
    Units: sectors of 1 * 512 = 512 bytes
    Sector size (logical/physical): 512 bytes / 512 bytes
    I/O size (minimum/optimal): 512 bytes / 512 bytes
    Disklabel type: dos
    Disk identifier: 0x64aa5f59
    
    root@vagrant:~# fdisk -l
    __________________________________________________________
    Device     Boot   Start     End Sectors  Size Id Type
    /dev/sdb1          2048 4196351 4194304    2G 83 Linux
    /dev/sdb2       4196352 5242879 1046528  511M 83 Linux
    
    
    Disk /dev/sdc: 2.51 GiB, 2684354560 bytes, 5242880 sectors
    Disk model: VBOX HARDDISK   
    Units: sectors of 1 * 512 = 512 bytes
    Sector size (logical/physical): 512 bytes / 512 bytes
    I/O size (minimum/optimal): 512 bytes / 512 bytes
    Disklabel type: dos
    Disk identifier: 0x64aa5f59
    
    Device     Boot   Start     End Sectors  Size Id Type
    /dev/sdc1          2048 4196351 4194304    2G 83 Linux
    /dev/sdc2       4196352 5242879 1046528  511M 83 Linux   
    ```

1. Соберите `mdadm` RAID1 на паре разделов 2 Гб.

    **Ответ:**  

    ```bash
    root@vagrant:~# mdadm --create --verbose /dev/md1 --level 1 --raid-devices=2 /dev/sd{b1,c1}
    mdadm: Note: this array has metadata at the start and
        may not be suitable as a boot device.  If you plan to
        store '/boot' on this device please ensure that
        your boot-loader understands md/v1.x metadata, or use
        --metadata=0.90
    mdadm: size set to 2094080K
    Continue creating array? y
    mdadm: Defaulting to version 1.2 metadata
    mdadm: array /dev/md1 started.
    ```

1. Соберите `mdadm` RAID0 на второй паре маленьких разделов.

    **Ответ:**  

    ```bash
    root@vagrant:~# mdadm --create --verbose /dev/md0 --level 0 --raid-devices=2 /dev/sd{b2,c2}
    mdadm: chunk size defaults to 512K
    mdadm: Defaulting to version 1.2 metadata
    mdadm: array /dev/md0 started.
    root@vagrant:~# lsblk
    NAME                 MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINT
    sda                    8:0    0   64G  0 disk  
    ├─sda1                 8:1    0  512M  0 part  /boot/efi
    ├─sda2                 8:2    0    1K  0 part  
    └─sda5                 8:5    0 63.5G  0 part  
      ├─vgvagrant-root   253:0    0 62.6G  0 lvm   /
      └─vgvagrant-swap_1 253:1    0  980M  0 lvm   [SWAP]
    sdb                    8:16   0  2.5G  0 disk  
    ├─sdb1                 8:17   0    2G  0 part  
    │ └─md1                9:1    0    2G  0 raid1 
    └─sdb2                 8:18   0  511M  0 part  
      └─md0                9:0    0 1018M  0 raid0 
    sdc                    8:32   0  2.5G  0 disk  
    ├─sdc1                 8:33   0    2G  0 part  
    │ └─md1                9:1    0    2G  0 raid1 
    └─sdc2                 8:34   0  511M  0 part  
      └─md0                9:0    0 1018M  0 raid0  
    ```

1. Создайте 2 независимых PV на получившихся md-устройствах.

    **Ответ:**  

    ```bash
    root@vagrant:~# pvcreate /dev/md1 /dev/md0
      Physical volume "/dev/md1" successfully created.
      Physical volume "/dev/md0" successfully created.
    ```

1. Создайте общую volume-group на этих двух PV.

    **Ответ:**  

    ```bash
    root@vagrant:~# vgcreate vg1 /dev/md1 /dev/md0
      Volume group "vg1" successfully created
    root@vagrant:~# vgdisplay
      --- Volume group ---
      VG Name               vgvagrant
      System ID             
      Format                lvm2
      Metadata Areas        1
      Metadata Sequence No  3
      VG Access             read/write
      VG Status             resizable
      MAX LV                0
      Cur LV                2
      Open LV               2
      Max PV                0
      Cur PV                1
      Act PV                1
      VG Size               <63.50 GiB
      PE Size               4.00 MiB
      Total PE              16255
      Alloc PE / Size       16255 / <63.50 GiB
      Free  PE / Size       0 / 0   
      VG UUID               PaBfZ0-3I0c-iIdl-uXKt-JL4K-f4tT-kzfcyE
       
      --- Volume group ---
      VG Name               vg1
      System ID             
      Format                lvm2
      Metadata Areas        2
      Metadata Sequence No  1
      VG Access             read/write
      VG Status             resizable
      MAX LV                0
      Cur LV                0
      Open LV               0
      Max PV                0
      Cur PV                2
      Act PV                2
      VG Size               <2.99 GiB
      PE Size               4.00 MiB
      Total PE              765
      Alloc PE / Size       0 / 0   
      Free  PE / Size       765 / <2.99 GiB
      VG UUID               z1MeLB-Gjyp-ctpm-XFmq-u73p-K1zT-Qiod0S
    ```

1. Создайте LV размером 100 Мб, указав его расположение на PV с RAID0.

    **Ответ:**  

    ```bash
    root@vagrant:~# lvcreate -L 100M vg1 /dev/md0
      Logical volume "lvol0" created.
    root@vagrant:~# vgs
      VG        #PV #LV #SN Attr   VSize   VFree
      vg1         2   1   0 wz--n-  <2.99g 2.89g
      vgvagrant   1   2   0 wz--n- <63.50g    0 
    root@vagrant:~# lvs
      LV     VG        Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
      lvol0  vg1       -wi-a----- 100.00m                                                    
      root   vgvagrant -wi-ao---- <62.54g                                                    
      swap_1 vgvagrant -wi-ao---- 980.00m 

    ```  

1. Создайте `mkfs.ext4` ФС на получившемся LV.

    **Ответ:**  

    ```bash
    root@vagrant:~# mkfs.ext4 /dev/vg1/lvol0  
    mke2fs 1.45.5 (07-Jan-2020)  
    Creating filesystem with 25600 4k blocks and 25600 inodes
    
    Allocating group tables: done                            
    Writing inode tables: done                            
    Creating journal (1024 blocks): done
    Writing superblocks and filesystem accounting information: done

    ```

1. Смонтируйте этот раздел в любую директорию, например, `/tmp/new`.

    **Ответ:**  

    ```bash
    root@vagrant:~# mkdir /tmp/new  
    root@vagrant:~# mount /dev/vg1/lvol0 /tmp/new  
    root@vagrant:~# lsblk  
    NAME                 MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINT  
    sda                    8:0    0   64G  0 disk  
    ├─sda1                 8:1    0  512M  0 part  /boot/efi  
    ├─sda2                 8:2    0    1K  0 part  
    └─sda5                 8:5    0 63.5G  0 part  
      ├─vgvagrant-root   253:0    0 62.6G  0 lvm   /  
      └─vgvagrant-swap_1 253:1    0  980M  0 lvm   [SWAP]  
    sdb                    8:16   0  2.5G  0 disk  
    ├─sdb1                 8:17   0    2G  0 part  
    │ └─md1                9:1    0    2G  0 raid1 
    └─sdb2                 8:18   0  511M  0 part  
      └─md0                9:0    0 1018M  0 raid0 
        └─vg1-lvol0      253:2    0  100M  0 lvm   /tmp/new  
    sdc                    8:32   0  2.5G  0 disk  
    ├─sdc1                 8:33   0    2G  0 part  
    │ └─md1                9:1    0    2G  0 raid1 
    └─sdc2                 8:34   0  511M  0 part  
      └─md0                9:0    0 1018M  0 raid0 
        └─vg1-lvol0      253:2    0  100M  0 lvm   /tmp/new

    ```

1. Поместите туда тестовый файл, например `wget https://mirror.yandex.ru/ubuntu/ls-lR.gz -O /tmp/new/test.gz`.

    **Ответ:**  

    ```bash
    root@vagrant:~# wget https://mirror.yandex.ru/ubuntu/ls-lR.gz -O /tmp/new/test.gz  
    --2022-04-22 17:30:21--  https://mirror.yandex.ru/ubuntu/ls-lR.gz  
    Resolving mirror.yandex.ru (mirror.yandex.ru)... 213.180.204.183, 2a02:6b8::183  
    Connecting to mirror.yandex.ru (mirror.yandex.ru)|213.180.204.183|:443... connected.  
    HTTP request sent, awaiting response... 200 OK  
    Length: 22281866 (21M) [application/octet-stream]  
    Saving to: ‘/tmp/new/test.gz’  
    
    /tmp/new/test.gz                       100%            [============================================================================>]  21.25M  4.64MB/s    in 5.7s    
    
    2022-04-22 17:30:27 (3.75 MB/s) - ‘/tmp/new/test.gz’ saved [22281866/22281866]  
    
    root@vagrant:~# ls -l /tmp/new  
    total 21776  
    -rw-r--r-- 1 root root 22281866 Apr 22 17:05 test.gz  

    ```

1. Прикрепите вывод `lsblk`.

    **Ответ:**  

    ```bash
    root@vagrant:~# lsblk  
    NAME                 MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINT  
    sda                    8:0    0   64G  0 disk  
    ├─sda1                 8:1    0  512M  0 part  /boot/efi  
    ├─sda2                 8:2    0    1K  0 part  
    └─sda5                 8:5    0 63.5G  0 part  
      ├─vgvagrant-root   253:0    0 62.6G  0 lvm   /  
      └─vgvagrant-swap_1 253:1    0  980M  0 lvm   [SWAP]  
    sdb                    8:16   0  2.5G  0 disk  
    ├─sdb1                 8:17   0    2G  0 part  
    │ └─md1                9:1    0    2G  0 raid1 
    └─sdb2                 8:18   0  511M  0 part  
      └─md0                9:0    0 1018M  0 raid0 
        └─vg1-lvol0      253:2    0  100M  0 lvm   /tmp/new  
    sdc                    8:32   0  2.5G  0 disk  
    ├─sdc1                 8:33   0    2G  0 part  
    │ └─md1                9:1    0    2G  0 raid1 
    └─sdc2                 8:34   0  511M  0 part  
      └─md0                9:0    0 1018M  0 raid0 
        └─vg1-lvol0      253:2    0  100M  0 lvm   /tmp/new  
    ```

1. Протестируйте целостность файла:

    ```bash
    root@vagrant:~# gzip -t /tmp/new/test.gz
    root@vagrant:~# echo $?
    0
    ```

    **Ответ:**  

    ```bash
    root@vagrant:~# gzip -t /tmp/new/test.gz
    root@vagrant:~# echo $?
    0

    ```

1. Используя pvmove, переместите содержимое PV с RAID0 на RAID1.

    **Ответ:**  

    ```bash
    root@vagrant:~# pvmove /dev/md0
      /dev/md0: Moved: 36.00%
      /dev/md0: Moved: 100.00%
    root@vagrant:~# lsblk
    NAME                 MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINT
    sda                    8:0    0   64G  0 disk  
    ├─sda1                 8:1    0  512M  0 part  /boot/efi
    ├─sda2                 8:2    0    1K  0 part  
    └─sda5                 8:5    0 63.5G  0 part  
      ├─vgvagrant-root   253:0    0 62.6G  0 lvm   /
      └─vgvagrant-swap_1 253:1    0  980M  0 lvm   [SWAP]
    sdb                    8:16   0  2.5G  0 disk  
    ├─sdb1                 8:17   0    2G  0 part  
    │ └─md1                9:1    0    2G  0 raid1 
    │   └─vg1-lvol0      253:2    0  100M  0 lvm   /tmp/new
    └─sdb2                 8:18   0  511M  0 part  
      └─md0                9:0    0 1018M  0 raid0 
    sdc                    8:32   0  2.5G  0 disk  
    ├─sdc1                 8:33   0    2G  0 part  
    │ └─md1                9:1    0    2G  0 raid1 
    │   └─vg1-lvol0      253:2    0  100M  0 lvm   /tmp/new
    └─sdc2                 8:34   0  511M  0 part  
      └─md0                9:0    0 1018M  0 raid0 

    ```

1. Сделайте `--fail` на устройство в вашем RAID1 md.

    **Ответ:**  

    ```bash
    root@vagrant:~# mdadm /dev/md1 --fail /dev/sdb1  
    mdadm: set /dev/sdb1 faulty in /dev/md1  
    ```

1. Подтвердите выводом `dmesg`, что RAID1 работает в деградированном состоянии.

    **Ответ:**  

    ```bash
    root@vagrant:~# dmesg |grep md1
    [ 1129.000792] md/raid1:md1: not clean -- starting background reconstruction
    [ 1129.000797] md/raid1:md1: active with 2 out of 2 mirrors
    [ 1129.000833] md1: detected capacity change from 0 to 2144337920
    [ 1129.001359] md: resync of RAID array md1
    [ 1139.417728] md: md1: resync done.
    [ 4233.829806] md/raid1:md1: Disk failure on sdb1, disabling device.
                   md/raid1:md1: Operation continuing on 1 devices.

    ```

1. Протестируйте целостность файла, несмотря на "сбойный" диск он должен продолжать быть доступен:

    ```bash
    root@vagrant:~# gzip -t /tmp/new/test.gz
    root@vagrant:~# echo $?
    0
    ```

    **Ответ:**  

    ```bash
    root@vagrant:~# gzip -t /tmp/new/test.gz
    root@vagrant:~# echo $?
    0
    ```

1. Погасите тестовый хост, `vagrant destroy`.

    **Ответ:**  

    ```bash
        ~/Vagrant  vagrant destroy                                                                                                                        1 ✘  23s  
        default: Are you sure you want to destroy the 'default' VM? [y/N] y
    ==> default: Destroying VM and associated drives...
    ```