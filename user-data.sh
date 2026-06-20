#!/bin/bash

# Actualizamos el sistema antes de instalar cualquier servicio e instalamos nginx con el flag -y (si a todo)
apt update && apt install -y nginx

# enable nginx, para iniciar el servicio automaticamente en caso de reinicios
systemctl enable nginx

# start nginx, inicia el servicio justo ahora
systemctl start nginx

# Añadimos un texto simple en HTML a /var/www/html/index.html para confirmar que se creo correctamente
echo "<h1>Hola desde AWS EC2 User Data!</h1>" > /var/www/html/index.html

# Añadimos la hora de creado del User Data en los logs, /var/log/user-data.log
echo "User Data creado el $(date)" >> /var/log/user-data.log
