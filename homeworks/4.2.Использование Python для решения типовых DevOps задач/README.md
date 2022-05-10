# Домашнее задание к занятию "4.2. Использование Python для решения типовых DevOps задач"

1. Есть скрипт:
	```python
    #!/usr/bin/env python3
	a = 1
	b = '2'
	c = a + b
	```
	* Какое значение будет присвоено переменной c?
	* Как получить для переменной c значение 12?
	* Как получить для переменной c значение 3?  

    **Ответ:**  

  * Ошибка, т.к. для операции указанны типы int и str: TypeError: unsupported operand type(s) for +: 'int' and 'str'
  * привести a к строке: c=str(a)+b
  * привести b к целому числу: c=a+int(b).

2. Мы устроились на работу в компанию, где раньше уже был DevOps Engineer. Он написал скрипт, позволяющий узнать, какие файлы модифицированы в репозитории, относительно локальных изменений. Этим скриптом недовольно начальство, потому что в его выводе есть не все изменённые файлы, а также непонятен полный путь к директории, где они находятся. Как можно доработать скрипт ниже, чтобы он исполнял требования вашего руководителя?

	```python
    #!/usr/bin/env python3

    import os

	bash_command = ["cd ~/netology/sysadm-homeworks", "git status"]
	result_os = os.popen(' && '.join(bash_command)).read()
    is_change = False
	for result in result_os.split('\n'):
        if result.find('modified') != -1:
            prepare_result = result.replace('\tmodified:   ', '')
            print(prepare_result)
            break

	```

    **Ответ:**  
  * breake прерывает обработку при первом же найденом вхождении, поэтому в вывод попадают не все измененные файлы.  
  * путь к папке вынесен в переменную, выводится полный путь.  

	```python
	#!/usr/bin/env python3

    import os

    fullpath="~/devops-pu-netology"

    bash_command = ["cd "+fullpath, "git status"]
    #bash_command = ["cd ~/devops-pu-netology", "git    status"]
    result_os = os.popen(' && '.join(bash_command)).read()
    is_change = False
    for result in result_os.split('\n'):
        if result.find('modified') != -1:
            prepare_result = result.replace('\tmodified:   ', '').replace('#','')
            print(fullpath,prepare_result)

	```

3. Доработать скрипт выше так, чтобы он мог проверять не только локальный репозиторий в текущей директории, а также умел воспринимать путь к репозиторию, который мы передаём как входной параметр. Мы точно знаем, что начальство коварное и будет проверять работу этого скрипта в директориях, которые не являются локальными репозиториями.

    **Ответ:**  
Добавил путь до локального репозитория.  

	```python
	#!/usr/bin/env python3

	import os
	import argparse

	parser = argparse.ArgumentParser(description='Get Git modified files')
	parser.add_argument(
	    '-g',
	    type=str,
	    default='/home/vagrant/devops-pu-netology',
	    help='provide Git base path (default: /home/vagrant/devops-pu-netology)'
	    )
	args = parser.parse_args()

	bash_command = ["cd "+args.g, "git status"]
	result_os = os.popen(' && '.join(bash_command)).read()
	is_change = False
	for result in result_os.split('\n'):
	    if result.find('изменено') != -1:
	        prepare_result = result.replace('\tизменено:   ', '')
	        print(args.g,prepare_result)

	```

4. Наша команда разрабатывает несколько веб-сервисов, доступных по http. Мы точно знаем, что на их стенде нет никакой балансировки, кластеризации, за DNS прячется конкретный IP сервера, где установлен сервис. Проблема в том, что отдел, занимающийся нашей инфраструктурой очень часто меняет нам сервера, поэтому IP меняются примерно раз в неделю, при этом сервисы сохраняют за собой DNS имена. Это бы совсем никого не беспокоило, если бы несколько раз сервера не уезжали в такой сегмент сети нашей компании, который недоступен для разработчиков. Мы хотим написать скрипт, который опрашивает веб-сервисы, получает их IP, выводит информацию в стандартный вывод в виде: <URL сервиса> - <его IP>. Также, должна быть реализована возможность проверки текущего IP сервиса c его IP из предыдущей проверки. Если проверка будет провалена - оповестить об этом в стандартный вывод сообщением: [ERROR] <URL сервиса> IP mismatch: <старый IP> <Новый IP>. Будем считать, что наша разработка реализовала сервисы: drive.google.com, mail.google.com, google.com.  

    **Ответ:**  
 
	```python
    #!/usr/bin/env python3

    import socket as s
    import datetime as dt

    i = 1
    curl = {'drive.google.com':'0.0.0.0', 'mail.google.com':'0.0.0.0', 'google.com':'0.0.0.0'}
    init=0

    while 1==1 : 
      for host in curl:
        ip = s.gethostbyname(host)
        if ip != curl[host]:
          if i==1 and init !=1:
            print(curl(dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")) +' [ERROR] ' + str(host) +' несоответствие IP:       '+curl[host]+' '+ip)
          curl[host]=ip
      i+=1 
      if i >= 10 : 
        break

	```
