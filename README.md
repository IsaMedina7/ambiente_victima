# ambiente_victima

---

## 1. Arquitectura del Sistema

El laboratorio simula una red de defensa activa con los siguientes componentes:

| Servicio | Imagen | Función | IP Interna |
| :--- | :--- | :--- | :--- |
| **Firewall** | `gaia_firewall` | Gestión de tráfico (iptables) y NAT. | `10.5.0.5` |
| **Honeypot** | `cowrie/cowrie` | Trampa SSH para recolección de logs. | `10.5.0.20` |
| **Víctima** | `httpd:alpine` | Servidor web vulnerable detrás del firewall. | `10.5.0.10` |
| **Antivirus** | `clamav` | Escaneo de archivos en el directorio compartido. | Dinámica |
| **IDS Sniffer** | `gaia_sniffer` | Captura de tráfico en modo host (PCAP). | Modo Host |

---

## 2. Estrategia "Offline First"

Para evitar que los contenedores fallen al intentar descargar dependencias (`apk add`) durante el arranque, se implementó una estrategia de **Pre-construcción de Imágenes**:

1. **Inyección de binarios:** Se crearon Dockerfiles específicos (`Dockerfile.firewall` y `Dockerfile.sniffer`) que instalan `iptables` y `tcpdump` durante la fase de `build`.
2. **Eliminación de comandos dinámicos:** Se eliminaron las instrucciones `command: sh -c "apk add..."` del archivo `docker-compose.yml`, permitiendo que los servicios usen directamente los binarios ya presentes en la imagen local.

---

## 3. Configuración de Red y Flujo de Tráfico (NAT)

El **Firewall** actúa como el único punto de entrada (Gateway). Toda la comunicación externa pasa por él antes de llegar a los servicios internos:

* **Tráfico Web (8080 -> 80):** El tráfico que llega al puerto 8080 del Host es redirigido por el Firewall a la Víctima (`10.5.0.10`).
* **Tráfico de Ataque (2222 -> 2222):** El tráfico SSH que llega al puerto 2222 del Host es redirigido por el Firewall al Honeypot (`10.5.0.20`).

> **Nota Pro-Tip:** Se eliminaron los mapeos de puertos (`ports:`) directos en los servicios de la Víctima y el Honeypot para garantizar que el tráfico pase obligatoriamente por las reglas de `iptables` del Firewall.

---

## 4. Guía de Despliegue (Paso a Paso)

Si el sistema presenta errores de "puerto ya asignado" o comandos antiguos persistentes, siga este procedimiento de **Reset Total**:

### Paso 1: Limpieza Profunda

```bash
# Detener el proyecto y borrar volúmenes/redes
docker compose down --volumes --remove-orphans

# Eliminar procesos proxy de Docker que puedan retener puertos (8080/2222)
sudo killall docker-proxy 2>/dev/null

# Limpiar redes huérfanas
docker network prune -f
```

### Paso 2: Reconstrucción Local

```bash
# Construir imágenes con las herramientas ya instaladas
docker build -t gaia_firewall -f Dockerfile.firewall .
docker build -t gaia_sniffer -f Dockerfile.sniffer .
```

### Paso 3: Lanzamiento Forzado

```bash
# Forzar la recreación para ignorar el caché de contenedores viejos
docker compose up -d --force-recreate
```
