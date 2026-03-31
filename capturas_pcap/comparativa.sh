#!/bin/bash

# Ajusta los nombres a tus archivos reales
CAP_SIN="ataque_goldeneye_def.pcap"
CAP_CON="ataque_goldeneye_seg.pcap"

echo "-------------------------------------------------------"
echo "ANÁLISIS DE MITIGACIÓN DDOS - PROYECTO GAIA"
echo "-------------------------------------------------------"

# 1. Contar paquetes totales dirigidos AL servidor (Entrada)
TOTAL_SIN=$(tshark -r "$CAP_SIN" -Y "tcp.port == 80" 2>/dev/null | wc -l)
TOTAL_CON=$(tshark -r "$CAP_CON" -Y "tcp.port == 80" 2>/dev/null | wc -l)

# 2. Contar paquetes que el SERVIDOR envió de vuelta (Salida/Respuesta)
# Si el servidor responde mucho, es que el ataque lo está procesando.
RESP_SIN=$(tshark -r "$CAP_SIN" -Y "tcp.srcport == 80" 2>/dev/null | wc -l)
RESP_CON=$(tshark -r "$CAP_CON" -Y "tcp.srcport == 80" 2>/dev/null | wc -l)

echo "Escenario         | Tramas Totales | Respuestas Servidor | Eficacia"
echo "------------------|----------------|---------------------|-----------"

# Datos Sin Seguridad
echo "Sin Seguridad     | $TOTAL_SIN          | $RESP_SIN                | 0%"

# Cálculo de Mitigación (Cuanto tráfico se evitó que llegara al puerto 80)
DIFERENCIA=$((TOTAL_SIN - TOTAL_CON))
if [ "$TOTAL_SIN" -gt 0 ]; then
  EFICACIA=$(echo "scale=2; ($DIFERENCIA / $TOTAL_SIN) * 100" | bc)
else
  EFICACIA=0
fi

# Datos Con Seguridad
echo "Con Seguridad     | $TOTAL_CON          | $RESP_CON                | $EFICACIA%"
echo "-------------------------------------------------------"
echo "Interpretación: El Firewall filtró $((TOTAL_SIN - TOTAL_CON)) tramas maliciosas."
