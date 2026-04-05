# 🛡️ GAIA: Laboratorio de Defensa Activa e ID

Este proyecto despliega un entorno de red virtualizado diseñado para la simulación de ataques y análisis de tráfico (PCAP). La arquitectura integra capas de defensa (Firewall/Antivirus) y sistemas de engaño (Honeypot) en una infraestructura aislada.

---

## 1. Arquitectura del Sistema y Red LAN (`10.5.0.0/24`)

El laboratorio utiliza una red tipo `bridge` denominada `gaia_lab_net`. La configuración está diseñada para que el tráfico externo sea auditado antes de tocar los servicios críticos.

| Servicio | Imagen | IP Estática | Puertos (Host) | Función Principal |
| :--- | :--- | :--- | :--- | :--- |
| **gaia_firewall** | `gaia_firewall` | `10.5.0.5` | `8080`, `2222` | Gestión de tráfico (iptables), NAT y Gateway. |
| **victima_apache** | `httpd:alpine` | `10.5.0.10` | Interno (80) | Servidor web objetivo detrás del firewall. |
| **honeypot_gaia** | `cowrie/cowrie` | `10.5.0.20` | **`2223`** | Trampa SSH directa para recolección de logs puros. |
| **gaia_antivirus** | `clamav` | Dinámica | Interno | Escaneo de malware en volumen compartido `/html`. |
| **ids_sniffer** | `gaia_sniffer` | Modo Host | N/A | Captura de tráfico crudo (PCAP) para dataset de IA. |

---

## 2. Estrategia "Offline First" y Construcción

Para garantizar la estabilidad en entornos de laboratorio y evitar fallos por descargas fallidas en tiempo de ejecución:

1.  **Inyección de Binarios:** Las herramientas esenciales (`iptables`, `tcpdump`) se instalan durante la fase de `build` mediante los Dockerfiles específicos (`Dockerfile.firewall` y `Dockerfile.sniffer`).
2.  **Ejecución Local:** Se eliminaron los comandos dinámicos del `docker-compose.yml`, permitiendo que los servicios arranquen instantáneamente usando los binarios pre-instalados en las imágenes locales.

---

## 3. Configuración de Red y Flujo de Tráfico

### El Rol del Firewall (NAT)
El **Firewall** actúa como el único punto de entrada controlado para la víctima:
* **Tráfico Web (8080 -> 80):** El tráfico que llega al puerto `8080` del Host es redirigido por el Firewall a la Víctima (`10.5.0.10`).
* **Tráfico Administrativo (2222 -> 22):** Redirección segura para la gestión del contenedor firewall.

### Acceso al Honeypot (Estrategia de Engaño)
* **Puerto 2223 (Directo):** Se ha mapeado el puerto `2223` del Host directamente al Honeypot. Esto permite capturar ataques "puros" que no han sido filtrados o modificados por el Firewall, proporcionando datos de mayor calidad.

---

## 4. Guía de Despliegue y Reset Total

Si el sistema presenta errores de "puerto ya asignado" (`Bind for 0.0.0.0:2222 failed`) o persisten comportamientos de versiones antiguas, siga este procedimiento:

### Paso 1: Limpieza Profunda de Residuos

```bash
# 1. Detener el proyecto y borrar volúmenes/redes
docker compose down --volumes --remove-orphans

# 2. Eliminar procesos zombie de Docker que bloquean puertos (2222, 8080)
sudo kill -9 $(sudo lsof -t -i:2222) 2>/dev/null
sudo killall docker-proxy 2>/dev/null

# 3. Limpiar redes huérfanas
docker network prune -f
```

### Paso 2: Reconstrucción de Imágenes

```bash
# Construir las imágenes con las herramientas ya integradas
docker build -t gaia_firewall -f Dockerfile.firewall .
docker build -t gaia_sniffer -f Dockerfile.sniffer .
```

### Paso 3: Lanzamiento

```bash
# Forzar la recreación de contenedores
docker compose up -d --force-recreate
```

## 📂 Estructura de Datos y Monitoreo

- /capturas_pcap: Almacena los archivos .pcap generados por el sniffer.
- /html: Directorio compartido; cualquier archivo aquí será escaneado por el Antivirus.
- /logs: Logs de acceso de Apache para monitorear el éxito de ataques como GoldenEye.

## ✅ Verificación del Laboratorio

1. **Víctima:** `curl http://localhost:8080` (Debe responder el Apache).
2. **Honeypot:** `ssh root@localhost -p 2223` (Debe pedir password de Cowrie).
3. **Sniffer:** Verifica que aparezca un archivo nuevo en `./capturas_pcap/` tras realizar los comandos anteriores.

---
Desarrollado por el Grupo de Investigación GAIA - Universidad Nacional de Colombia.
