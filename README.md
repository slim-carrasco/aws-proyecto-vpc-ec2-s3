# VPC con EC2 y S3
Proyecto usando los servicios comunes de AWS, EC2 y S3, haciendo uso de subnetes, User Data y Bucket policy

# Servicios de AWS
|Servicios|Propósito|
|-----------|----------------|
|VPC|Crear un red en la nube, aislando y segmentando recurso con control total de IP, subnets y routing|
|S3|Almacenamiento en la nube|
|EC2|Ejecutar servidores virtuales|

# Tecnologias
|Tecnologias|Versión|Propósito|
|-----------|-------|---------|
|Nginx|1.30.2|Servidor web, peticiones|

# Lenguajes / Estándares
|Lenguaje|Propósito|
|-----------|--------|
|HTML|Pagina web|
|CSS|Estilos|

#Requisitos
- AWS CLI configurada
- Credenciales IAM con permisos sobre VPC, EC2 y S3
- Región: us-east-1

# Instalación y uso

## - Pasos
VPC con CIDR 10.0.0.0/16 — nómbrada vpc-proyecto
Una subnet pública con CIDR 10.0.1.0/24 en us-east-1a — nómbrada subnet-publica
Una subnet privada con CIDR 10.0.2.0/24 en us-east-1b — nómbrada subnet-privada
Un IGW adjunto a la VPC — nómbrado igw-proyecto
Agregar la ruta 0.0.0.0/0 → igw-proyecto que va dentro de rtb-publica

## - Creacion de la VPC
Creamos una vpc con el nombre de vpc-proyecto con CIDR 10.0.0.0/16
Creamos dos sub-redes asociadas a la vpc creada, subnet-publica, subnet-privada que sirven, subnet-publica para la creacion de instancia y la privada para la administración de recursos que no queremos que sean publicas como una DB
Creamos la puerta de enlace IGW(Internet Gateway) y la adjuntamos a la VPC
La Main Route Table se dispone al crear la VPC, la Main RT no debe tener ruta a internet para que las subnetes no queden explicitamente conectadas debido a la herencia, en caso de que este conectada a internet la VPC y las subnetes que posee dejarian de ser privadas
Creamos otra tabla de enrutamiento para la subnet publica nombrada "rtb-publica" que tenga asociada a la subnet publica subnet-publica ademas de dos rutas, "local(10.0.0.0/16)" y "0.0.0.0/0"que debe asociarse a la IGW para la ruta a internet
Activamos la auto-assing de IP publica que sirve para asignar IP automaticamente a las instancias 

## - Creacion de la instancia
- Creamos la instancia en EC2, Ubuntu24.. con tipo t3.micro, asignamos la subnet publica previamente habilita la opcion de auto-assign, creamos un nuevo security group, entradas de la security group nuestra ip para SSH puerto 22 y HTTP para todo el mundo puerto 80

- Se requiere una Key Pair para acceder a la instancia mediante SSH, esta se crea al momento de crearla instancia y nos da un .pem para el acceso, el .pem si lo pierdes se pierde el acceso, guardarlo en un lugar seguro

- Configuramos el User Data

``` bash

#!/bin/bash

#Actualizamos el sistema antes de instalar cualquier servicio e instalamos nginx con el flag -y(si a todo)
apt update && apt install -y nginx

#enable nginx, para iniciar el servicio automaticamente en caso de reinicios
systemctl enable nginx

#start nginx, inicia el servicio justo ahora
systemctl start nginx

#Añadimos un texto simple en HTML a /var/www/html/index.html para confirmar que se creo correctamente
echo "<h1>Hola desde AWS EC2 User Data!</h1>" > /var/www/html/index.html

#Añadimos la hora de creado del User Data en los logs, /var/log/user-data.log
echo "User Data creado el $(date)" >> /var/log/user-data.log

```
- Verificar
```bash
# Verificamos si esta activo y corriendo
sudo systemctl is-enabled nginx && sudo systemctl is-active nginx

# Se debe mostrar el codigo del .html
cat /var/www/html/index.html

# Se debe mostrar el log del momento de la creacion del User Data
cat /var/log/user-data.log

```

- URL
→ /var/www/html/index.html → accesible en http://<EC2-PUBLIC-IP>/ ejemplo -> http://3.80.173.211/
→ s3://assets-proyecto-slim/*" → archivo .css, accesible en https://assets-proyecto-slim.s3.us-east-1.amazonaws.com/style.css

##Creacion del bucket en S3
Creamos un bucket assets-proyecto-slim con la ocpion de Bloquear acceso Publico desactivada, Control de version de objetos activada
Creamos un archivo .css simple y lo subimos al bucket con:
```bash
aws s3 cp style.css s3://assets-proyecto-slim
```
Una vez subido el archivo lo hacemos publico con buckets policy, dentro de las opciones del bucket creado previamente

Creamos una Bucket Policy
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::assets-proyecto-slim/*"
        }
    ]
}
```
- "Version": "2012-10-17", -> Por defecto siempre la indicada
- "Statement": [ ] -> Arreglo que contine todas las reglas de la policy
- "Effect": "Allow", -> Efecto permitir
- "Principal": "*", -> Acceso a todos(*), acceso publico sin restriccion de identidad
- "Action": "s3:GetObject", -> Accion obtener el objeto 
- "Resource": "arn:aws:s3:::assets-proyecto-slim/*" -> Recurso "/*" indica todo lo que este dentro de assets-proyecto-slim
     
Obtenemos el link del objeto y añadimos al html para que se aplique el estilo
¿Por que no hacer los estilos .css directamente en el HTML?
Porque si ese estilo sirve a muchos archivos, ademas de que si la instancia se cae, se elimina, escala, o se reemplaza los estilos seguiran disponibles ademas de que S3 provee para usar en paginas estaticas ahorrando recursos

## CloudWatch
Parte 1 -- CloudWAtch Alarm + SNS
Se configuro para analizar metricas del consumo del cpu se uso la metrica CPUUtilization, la alarma es nombrada alarma-cpu-ec2-proyecto y que al momento de superar el umbral del 70%/5 minutos, llegar un mensaje al correo asociado mediante SNS ejemplo usuario@gmail.com


Parte 2 -- IAM Role + Cloudwatch agent
Se creo un IAM Role para adjuntar a la instancia previamente creada, que permita a la  ec2  usar CloudWatch, el rol fue nombrado role-ec2-cloudwatch mediante la policy CloudWatchAgentServerPolicy que específicamente nos permite autorizar métricas personalizadas como (Ram, disco), mandar logs, leer su propia configuración, además de permitir escribir hacia CloudWatch

Una vez adjuntado entramos al servidor para instalar CloudWatch Agent
La url de CloudWatch Agent es:
https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb

Descargamos con wget
```bash
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
```
Una vez descargado instalamos el paquete .deb:
```bash
sudo dpkg -i amazon-cloudwatch-agent.deb 
```
Creamos el archivo de configuración en la ruta "/opt/aws/amazon-cloudwatch-agent/etc/config.json"
```bash
sudo nano /opt/aws/amazon-cloudwatch-agent/etc/config.json
```
Se uso el siguiente codigo:
```json
{

  "logs": {

    "logs_collected": {

      "files": {

        "collect_list": [

          {

            "file_path": "/var/log/nginx/access.log",

            "log_group_name": "nginx-access-logs",

            "log_stream_name": "{instance_id}"

          },

          {

            "file_path": "/var/log/nginx/error.log",

            "log_group_name": "nginx-error-logs",

            "log_stream_name": "{instance_id}"

          }

        ]

      }

    }

  }

}
```
Crea dos grupos uno para accesos otro para errores, "log_stream_name: {instance_id}", variable que se reemplaza automáticamente por el Instance ID real de la EC2, sirve apra diferenciar logs en caso pertenecer al mismo log group

Iniciamos el agent con:
```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
```

Dejamos el agente con autostart para que en caso de reinicios inicie automaticamente:
```bash
sudo systemctl enable amazon-cloudwatch-agent
```

Verificamos:
```bash
sudo systemctl status amazon-cloudwatch-agent
```

Los logs se pueden ver en: CloudWatch -> Registros -> Administrador de registros, y seleccionar el grupo de registro creado

##Arquitectura
El usuario esta en internet y entra a la infraestructura mediante IGW que redirije todo el trafico a la VPC
La VPC posee dos subredes una publica(subnet-publica) y una privada(subnet-privada)
Se tiene dos RT la Main Route Table que es para uso privado y otra que es la rtb-publica a la que esta asociada la subnet-publica y el acceso a internet mediante IGW
Main RT(vpc-proyecto) solo esta asociado a la subnet-privada
En este caso la peticion se dirige a la publica donde se encuentra la instancia corriendo con el servicio de nginx donde tenemos una pagina web simple, S3 provee los estilo a la pagina
La subred privada esta reservada para base de datos

```text
Usuario
    │
Internet
    │
  IGW (igw-proyecto)
    │
  VPC (10.0.0.0/16)
    ├── subnet-publica (10.0.1.0/24)
    │       │
    │     EC2 (nginx) ──── S3 (assets-proyecto-slim)
    │
    └── subnet-privada (10.0.2.0/24)
            │
          (vacía - reservada para DB)

```
# Estructura
aws-proyecto-vpc-ec2-s3/
├── README.md - Documentacion
├── user-data.sh - User Data que se ejcuta al momento de crea la instancia(unica vez)
├── style.css - Estilo simple usado en la pagina web dentro de S3
└── index.html - Pagina simple usada par ala demostracion 

# Problemas comunes
IP dinámica que cambia, pierdes acceso SSH -> Solución correcta: VPN o Bastion Host, el puerto 22 no debe estar expuesto directo a internet

# Próximas mejoras
- [ ] IP publica sin dominio ni load balancer en la EC2
- [ ] Añadir HTTPS sobre HTTP
- [ ] Añadir auto scaling
- [ ] Añadir DB

# Características técnicas
- Separacion de assets estaticos en S3
- Aislamiento de red mediante subnetes
- User Data con configuracion automatica
- IAM Role con permisos minimos para CloudWatch
- Separacion de logs (access/error) en distintos log groups con CloudWatch Agent
