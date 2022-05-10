# Домашнее задание к занятию "4.3. Языки разметки JSON и YAML"

1. Мы выгрузили JSON, который получили через API запрос к нашему сервису:
	```json
    { "info" : "Sample JSON output from our service\t",
        "elements" :[
            { "name" : "first",
            "type" : "server",
            "ip" : 7175 
            },
            { "name" : "second",
            "type" : "proxy",
            "ip : 71.78.22.43
            }
        ]
    }
	```
  Нужно найти и исправить все ошибки, которые допускает наш сервис

    **Ответ:**  

  Нехватает ковычек во втором эелементе:

	```json
    { "info" : "Sample JSON output from our service\t",
        "elements" :[
            { "name" : "first",
            "type" : "server",
            "ip" : 7175 
            },
            { "name" : "second",
            "type" : "proxy",
            "ip" : "71.78.22.43"
            }
        ]
    }
	```

2. В прошлый рабочий день мы создавали скрипт, позволяющий опрашивать веб-сервисы и получать их IP. К уже реализованному функционалу нам нужно добавить возможность записи JSON и YAML файлов, описывающих наши сервисы. Формат записи JSON по одному сервису: { "имя сервиса" : "его IP"}. Формат записи YAML по одному сервису: - имя сервиса: его IP. Если в момент исполнения скрипта меняется IP у сервиса - он должен так же поменяться в yml и json файле.

    **Ответ:**  

	```python
    #!/usr/bin/env python3

    import socket as s
    import datetime as dt
    import json
    import yaml
    
    i = 1
    curl = {'drive.google.com':'0.0.0.0', 'mail.google.com':'0.0.0.0', 'google.com':'0.0.0.0'}
    init=0
    fpath = "/home/vagrant/hw4.3/"
    flog  = "/home/vagrant/hw4.3/error.log"
    
    while True :
      for host in curl:
        is_error = False
        ip = s.gethostbyname(host)
        if ip != curl[host]:
          if i==1 and init !=1:
            is_error=True
            with open(flog,'a') as fl:
              print(str(dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")) +' [ERROR] ' + str(host) +' IP mistmatch: '+curl[host]+' '+ip,file=fl)
    
            with open(fpath+host+".json",'w') as jsf:
              json_data= json.dumps({host:ip})
              jsf.write(json_data)
    
            with open(fpath+host+".yaml",'w') as ymf:
              yaml_data= yaml.dump([{host : ip}])
              ymf.write(yaml_data)
    
        if is_error:
          data = []
          for host in curl:
            data.append({host:ip})
          with open(fpath+"services_conf.json",'w') as jsf:
            json_data= json.dumps(data)
            jsf.write(json_data)
          with open(fpath+"services_conf.yaml",'w') as ymf:
            yaml_data= yaml.dump(data)
            ymf.write(yaml_data)
            curl[host]=ip
      i+=1
      if i >= 10 :
        break
	```

