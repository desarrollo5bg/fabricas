📄 Manual de Configuración - Entorno de Pruebas API Quac (.NET)

📌 1. Información General del Entorno

  - Servidor (IP): 192.168.31.108
  - Sistema Operativo: Linux
  - Tecnología: .NET (API REST)
  - Dominio Público: https://apiquac-dev.baguer.app/
  - Puerto Interno de Ejecución: 5005
  - Usuario FTP / Propietario de archivos: baguer

📂 2. Ubicación de Archivos y Permisos

Los archivos compilados (resultado de dotnet publish) se alojan en la siguiente
ruta dentro del servidor:

  - Ruta absoluta: /home/apiquac-dev

Gestión de Permisos: La carpeta fue configurada para que pertenezca al usuario
baguer. Esto permite que las actualizaciones de código se puedan subir por FTP
sin problemas de permisos bloqueados por el usuario root.

  - Comando de propiedad usado: chown -R baguer:baguer /home/apiquac-dev

⚙️ 3. Servicio de Segundo Plano (Systemd)

Para garantizar que la API de .NET se ejecute de forma continua, se inicie con
el servidor y se recupere ante fallos, se creó un servicio demonio en Linux.

  - Nombre del servicio: apiquac-dev.service
  - Ubicación del archivo de configuración:
    /etc/systemd/system/apiquac-dev.service

Configuración clave del servicio:

  - Directorio de trabajo: /home/apiquac-dev
  - Comando de ejecución: /usr/bin/dotnet /home/apiquac-dev/[NombreDeTuDll].dll
  - Entorno: Production (Variable ASPNETCORE_ENVIRONMENT)
  - URL Interna: http://127.0.0.1:5005

🌐 4. Servidor Web y Proxy Inverso (Nginx)

Nginx se configuró como Reverse Proxy para recibir el tráfico de internet a
través de los puertos 80 (HTTP) y 443 (HTTPS) y redirigirlo internamente al
puerto 5005 de la API.

  - Ubicación del archivo de configuración: /etc/nginx/conf.d/apiquac-dev.conf
  - Redirección de tráfico: Todo el tráfico HTTP (puerto 80) se fuerza
    automáticamente a HTTPS (puerto 443) mediante una redirección 301.

Certificados SSL (Seguridad): Se reutilizó el certificado Wildcard corporativo
existente para el dominio *.baguer.app, alojado en:

  - Certificado: /etc/nginx/ssl/baguer_app_wildcard/baguer_app_fullchain.crt
  - Llave Privada: /etc/nginx/ssl/baguer_app_wildcard/baguer_app.key

🛠️ 5. Guía Operativa (Comandos Frecuentes)

Si necesitas actualizar la API en el futuro con nuevos cambios de código, este
es el flujo a seguir:

Paso 1: Subir archivos Sube los nuevos archivos compilados por FTP a la carpeta
/home/apiquac-dev con tu usuario baguer (puedes sobreescribir los archivos
existentes).

Paso 2: Reiniciar la API (Systemd) Para que la API tome los nuevos cambios,
conéctate por SSH y ejecuta:

sudo systemctl restart apiquac-dev.service

Paso 3: Ver los logs en tiempo real (Opcional) Si la API falla o quieres ver los
logs de la consola en vivo, utiliza este comando:

sudo journalctl -u apiquac-dev.service -f

Otros comandos útiles:

  - Ver estado de la API: sudo systemctl status apiquac-dev.service
  - Verificar sintaxis de Nginx: sudo nginx -t
  - Recargar Nginx (si modificas el .conf): sudo systemctl reload nginx

Fin del documento.