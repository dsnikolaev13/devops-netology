# Домашнее задание к занятию "3.2. Работа в терминале, лекция 2"

1. Какого типа команда `cd`? Попробуйте объяснить, почему она именно такого типа; опишите ход своих мыслей, если считаете что она могла бы быть другого типа.  

    **Ответ:**
`type cd` cd - это соманда встроенная в сам shell, она выполняется самостоятельно в текущей сессии, не вызывая отдельный исполняемый файл. Если бы использовался внешний вызов, то он изменил бы каталог только для этого внешнего процесса, сам shell останется в том же каталоге.  

1. Какая альтернатива без pipe команде `grep <some_string> <some_file> | wc -l`? `man grep` поможет в ответе на этот вопрос. Ознакомьтесь с [документом](http://www.smallo.ruhr.de/award.html) о других подобных некорректных вариантах использования pipe.

    **Ответ:**
    `grep <some_string> <some_file> -c` Опция `-c` выведет в spdout количество совпадений строк

1. Какой процесс с PID `1` является родителем для всех процессов в вашей виртуальной машине Ubuntu 20.04?  

    **Ответ:**
    Дерево процесов `pstree -p` наглядно покажет родителя всех процессов - systemd `ps -p 1` передаст в stdout CMD - имя процесса с PID 1  
   
1. Как будет выглядеть команда, которая перенаправит вывод stderr `ls` на другую сессию терминала?

    **Ответ:**
    `vagrant@vagrant:~$ ls 123 2> /dev/pts/1` Т.к. каталог `vagrant` у меня не содержит каталога 123, `ls` вызовет `stderr`, далее что бы перенаправить именно `stderr` нужно указать его дискриптор - 2. Далее пернаправляем его в нужный tty

1. Получится ли одновременно передать команде файл на stdin и вывести ее stdout в другой файл? Приведите работающий пример.

    **Ответ:**
    ```bash
    [команда] < [фаил] > [stdout]  
    vagrant@vagrant:~$ ls  
    exemple.txt  
  
    vagrant@vagrant:~$ cat exemple.txt  
    LS  
    RM  
    DDup  
    ddUP  
    mk  
    rs  
   
    vagrant@vagrant:~$ tr 'a-z' 'A-Z' `< exemple.txt >` exemple_up.txt  
   
    vagrant@vagrant:~$ ls  
    exemple.txt   
    exemple_up.txt  
  
    vagrant@vagrant:~$ cat exemple_up.txt  
    LS  
    RM  
    DDUP  
    DDUP  
    MK  
    RS  
    ``` 

1. Получится ли находясь в графическом режиме, вывести данные из PTY в какой-либо из эмуляторов TTY? Сможете ли вы наблюдать выводимые данные?

    **Ответ:**
    Можно перенаправить вывод на TTY, например: `echo test >/dev/tty2`. Находясь в графическом режиме выводимые данные мы не увидим, но переключившись в эмулятор TTY вывод будет видно. Переключиться можно `cntrl+alt+F2`. По F1 у меня не переключается в TTY.
    
1. Выполните команду `bash 5>&1`. К чему она приведет? Что будет, если вы выполните `echo netology > /proc/$$/fd/5`? Почему так происходит?  

    **Ответ:**
    Команда `bash 5>&1` создаст дескриптор 5 для stdout. Команда `echo netology > /proc/$$/fd/5`перенаправит вывод в дискриптор 5 который будет перенаправлен в stdout. Результат будет выглядеть как `echo netology` или `echo netology > /proc/$$/fd/1`, но в этом случае вывод будет в стандартный stdout с дискриптором 1.  
1. Получится ли в качестве входного потока для pipe использовать только stderr команды, не потеряв при этом отображение stdout на pty? Напоминаем: по умолчанию через pipe передается только stdout команды слева от `|` на stdin команды справа.
Это можно сделать, поменяв стандартные потоки местами через промежуточный новый дескриптор, который вы научились создавать в предыдущем вопросе.  

   **Ответ:**
`ls && ls 123 4>&2 2>&1 1>&4 |wc -w`. В данном случае 4 - новый, промежуточный дискриптор, `4>&2` - перенапрявляет новый дискриптор в stderr, `2>&1` - stderr перенаправляется в stdout, а stdout перенаправляется в новый дискриптор `1>&4`. `wc -w` покажет количество слов в stderr.  

    ```bash
	vagrant@vagrant:~$ ls && ls 123  
        test.txt
        ls: cannot access '123': No such file or directory

        vagrant@vagrant:~$ ls && ls 123 4>&2 2>&1 1>&4 |wc -w
        test.txt
        9
    ```

1. Что выведет команда `cat /proc/$$/environ`? Как еще можно получить аналогичный по содержанию вывод?

    **Ответ:**
Команда выводит переменные окрыжения, также как `env`.    
    
1. Используя `man`, опишите что доступно по адресам `/proc/<PID>/cmdline`, `/proc/<PID>/exe`.

    **Ответ:**
`/proc/<PID>/cmdline`- полный путь до исполняемого файла процесса `<PID>`, `/proc/<PID>/exe`- ссылка до файла запущенного для процесса `<PID>`. 
1. Узнайте, какую наиболее старшую версию набора инструкций SSE поддерживает ваш процессор с помощью `/proc/cpuinfo`.

    **Ответ:**
sse4_2
 
1. При открытии нового окна терминала и `vagrant ssh` создается новая сессия и выделяется pty. Это можно подтвердить командой `tty`, которая упоминалась в лекции 3.2. Однако:

    ```bash
	vagrant@netology1:~$ ssh localhost 'tty'
	not a tty
    ```

	Почитайте, почему так происходит, и как изменить поведение.  
	
   **Ответ:**
Потому что по умолчанию для удаленного хоста не запускается TTY, а мы пытаемся запустить команду на удаленном хосте. Когда же мы запускаем `vagrant ssh` без удаленной команды ssh ожидает что будет запущена оболочка и выделяет TTY. Можно принудительно запустить TTY на удаленном хосте при запуске команды, указав параметр -t : `ssh -t localhost 'tty'`  
1. Бывает, что есть необходимость переместить запущенный процесс из одной сессии в другую. Попробуйте сделать это, воспользовавшись `reptyr`. Например, так можно перенести в `screen` процесс, который вы запустили по ошибке в обычной SSH-сессии.  

   **Ответ:**
`screen reptyr <PID>` - переместить процесс в screen, сессия терминала при этом освободится. Попробовал переместить процесс в другую сессию терминала, взял PID процесса top, `sudo reptyr -T <PID>`.  
1. `sudo echo string > /root/new_file` не даст выполнить перенаправление под обычным пользователем, так как перенаправлением занимается процесс shell'а, который запущен без `sudo` под вашим пользователем. Для решения данной проблемы можно использовать конструкцию `echo string | sudo tee /root/new_file`. Узнайте что делает команда `tee` и почему в отличие от `sudo echo` команда с `sudo tee` будет работать.  

   **Ответ:**
    `tee` разделяет вывод на два потока, один в `stdout`, другой - в фаил. В конструкции `echo string | sudo tee /root/new_file` команда    `tee` получает на `stdin` перенаправленный `stdout` команды `echo`, запишет результат в `/root/new_file` т.к. запущена от sudo, и выведет на `stdout`

 
 ---

