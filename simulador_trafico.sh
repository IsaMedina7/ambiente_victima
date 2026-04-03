#!/bin/bash
# Simulador de actividad de usuario GAIA
TARGET="http://192.168.10.40:8080/"

echo "Iniciando simulación de tráfico legítimo hacia $TARGET..."
echo "Presiona [CTRL+C] para detener."

while true; do
  # Realiza una petición y mide el tiempo
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET")
  TIME=$(curl -s -o /dev/null -w "%{time_total}" "$TARGET")

  if [ "$HTTP_CODE" -eq 200 ]; then
    echo "[OK] Usuario accedió en ${TIME}s"
  else
    echo "[FALLO] Error $HTTP_CODE - El servidor no responde a tiempo"
  fi

  # Espera un tiempo aleatorio entre 0.1 y 0.5 segundos para parecer humano
  sleep 0.$(($RANDOM % 5 + 1))
done
