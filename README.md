﻿Denis Nikolaev

# Домашнее задание к занятию "3.1. Работа в терминале"

1. Установите средство виртуализации [Oracle VirtualBox](https://www.virtualbox.org/).

	* pacman -S virtualbox

1. Установите средство автоматизации [Hashicorp Vagrant](https://www.vagrantup.com/).

	* pacman -S vagrant

1. В вашем основном окружении подготовьте удобный для дальнейшей работы терминал. Можно предложить:

	* Использую эмулятор терминала Konsole. Настроил цветовую схему.

1. С помощью базового файла конфигурации запустите Ubuntu 20.04 в VirtualBox посредством Vagrant:

	* Создал директорию Vagrant. Перешел в созданную директорию и выполнил `vagrant init`, создался конфигурационный фаил. Отредактировал config.vm.box
	* Выполнил `vagrant up`, образ дистрибутива Ubuntu установленн на VM и запущен.
	* Выключил `vagrant halt`.

1. Ознакомьтесь с графическим интерфейсом VirtualBox, посмотрите как выглядит виртуальная машина, которую создал для вас Vagrant, какие аппаратные ресурсы ей выделены. Какие ресурсы выделены по-умолчанию?  

        RAM:1024mb  
        CPU:2   
        HDD:64gb  
        video:20mb

1. Ознакомьтесь с возможностями конфигурации VirtualBox через Vagrantfile: [документация](https://www.vagrantup.com/docs/providers/virtualbox/configuration.html). Как добавить оперативной памяти или ресурсов процессора виртуальной машине?  

	* В фале Vagrantfile указать следующее:
	  config.vm.provider "virtualbox" do |vb|  
              vb.memory = "2048"  
              vb.cpu = "4"  
          end

1. Команда `vagrant ssh` из директории, в которой содержится Vagrantfile, позволит вам оказаться внутри виртуальной машины без каких-либо дополнительных настроек. Попрактикуйтесь в выполнении обсуждаемых команд в терминале Ubuntu.  

       * Подключился по ssh к VM командой vagrant ssh. Параметры подключения, имя хоста узнал командой vagrant ssh-config.

1. Ознакомиться с разделами `man bash`, почитать о настройках самого bash:
    * Задать длину журнала `history` можно переменной HISTFILESIZE - максимальное количество строк содержащихся в файле истории. Строка 721 manual.  
      Или HISTSIZE - количество команд которое запоминается в истории. Строка 733.
    * Директива `ignoreboth` в bash является сокращением для ignorespace и ignoredups. Если список значений включает ignoresp вce строки, начинающиеся с символа пробела, не сохраняются в списке истории. Значение ignoredups приводит к тому, что строки, соответствующие предыдущей записи в истории не сохраняются.

1. В каких сценариях использования применимы скобки `{}` и на какой строчке `man bash` это описано?

    * 926

1. С учётом ответа на предыдущий вопрос, как создать однократным вызовом `touch` 100000 файлов? Получится ли аналогичным образом создать 300000? Если нет, то почему?
1. В man bash поищите по `/\[\[`. Что делает конструкция `[[ -d /tmp ]]`
1. Основываясь на знаниях о просмотре текущих (например, PATH) и установке новых переменных; командах, которые мы рассматривали, добейтесь в выводе type -a bash в виртуальной машине наличия первым пунктом в списке:

	```bash
	bash is /tmp/new_path_directory/bash
	bash is /usr/local/bin/bash
	bash is /bin/bash
	```

	(прочие строки могут отличаться содержимым и порядком)
    В качестве ответа приведите команды, которые позволили вам добиться указанного вывода или соответствующие скриншоты.

1. Чем отличается планирование команд с помощью `batch` и `at`?

1. Завершите работу виртуальной машины чтобы не расходовать ресурсы компьютера и/или батарею ноутбука.

	* Выключил `vagrant suspend`. 

