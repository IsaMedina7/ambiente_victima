# ambiente_victima

Este proyecto levanta un entorno simulado con múltiples servicios de seguridad (IDS, firewall, antivirus, honeypot y máquina víctima) usando Docker.

1. Clonar el repositorio
```bash
git clone git@github.com:IsaMedina7/ambiente_victima.git
```

2. Entrar al repositorio
```bash
cd ambiente_victima
```

3. Construir y levantar los contenedores
```bash
docker compose up --build
```

4. Verificar que todo esté funcionando
```bash
docker ps
```

Debe indicar que todos los contenedores están en estado UP.

Ejemplo:
```bash
docker ps -a

CONTAINER ID   IMAGE                  COMMAND                  CREATED          STATUS                             PORTS                                                   NAMES
df003f420557   nicolaka/netshoot      "tail -f /dev/null"      27 seconds ago   Up 25 seconds                                                                              ids_gaia
4218d8b07cc1   cowrie/cowrie:latest   "/cowrie/cowrie-env/…"   28 seconds ago   Up 26 seconds                      0.0.0.0:2222->2222/tcp, [::]:2222->2222/tcp, 2223/tcp   honeypot_gaia
ed54e098d0c7   httpd:2.4-alpine       "httpd-foreground"       28 seconds ago   Up 27 seconds                      0.0.0.0:8080->80/tcp, [::]:8080->80/tcp                 victima_apache
afdfe9ad179c   alpine                 "/bin/sh -c 'apk add…"   28 seconds ago   Up 26 seconds                                                                              gaia_firewall
e3ed74d12f18   clamav/clamav:latest   "/init"                  28 seconds ago   Up 26 seconds (health: starting)   3310/tcp, 7357/tcp                                      gaia_antivirus
bbc2e72e93a3   nicolaka/netshoot      "zsh"                    3 days ago       Exited (0) 3 days ago                                                                      vigilant_snyder
```

Para monitorear el comportamiento de los servicios:

IDS (captura de paquetes):
```bash
docker exec -it ids_gaia tcpdump -i any port 80 -A -nn
```

Firewall:
```bash
docker exec -it gaia_firewall watch -n 1 iptables -L -v -n
```

Antivirus:
```bash
docker logs -f gaia_antivirus
```

Máquina víctima:
```bash
docker logs -f victima_apache
```

Honeypot:
```bash
docker logs -f honeypot_gaia
```

Métricas de hardware:
```bash
docker stats
```

Análisis de red (modo detallado):
```bash
docker exec -it ids_gaia tcpdump -i any port 80 -A -vv
```

### termshark
´´´bash
docker exec -it ids_gaia termshark -i any
´´´

