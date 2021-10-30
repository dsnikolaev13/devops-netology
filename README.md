Denis Nikolaev

С помощью файла .gitignore в каталоге Terraform/ будут проигнорированны при добавлении в коммиты:

**/.terraform/* - все файлы в скрытом подкаталоге .terraform на любом уровне вложенности.

*.tfstate
*.tfstate.* - все файлы которые заканчиваются на .tfstate или содержат в теле названия вайла .tfstate.

crash.log - будут исключены файлы с названием crash и расширением .log (файлы журнала сбоев)

*.tfvars - файлы с расширением .tfvars

override.tf
override.tf.json
*_override.tf
*_override.tf.json - файлы override.tf override.tf.json и файлы, имена которых заканчиваются на _override.tf и _override.tf.json

.terraformrc
terraform.rc - файлы конфигурации CLI, файлы указанные в этом виде

Т.к. эти исключения указаны в файле .gitignore расположенном в каталоге Terraform, они будут применены к файлам и каталогам на уровне вложенности начиная от каталога в котором расположен
фаил .gitignore
