#!/bin/bash

CAP_SIN="control_normal_def.pcap"
CAP_CON="control_normal_seg.pcap"

echo "-------------------------------------------------------"
echo "ANÁLISIS DE TRÁFICO - PROYECTO GAIA"
echo "-------------------------------------------------------"

analizar() {
  FILE=$1

  SYN=$(tshark -r "$FILE" -Y "tcp.flags.syn==1 && tcp.flags.ack==0 && tcp.dstport==80" 2>/dev/null | wc -l)
  SYNACK=$(tshark -r "$FILE" -Y "tcp.flags.syn==1 && tcp.flags.ack==1 && tcp.srcport==80" 2>/dev/null | wc -l)
  HTTP=$(tshark -r "$FILE" -Y "http.request" 2>/dev/null | wc -l)

  echo "$SYN;$SYNACK;$HTTP"
}

DATA_SIN=$(analizar "$CAP_SIN")
DATA_CON=$(analizar "$CAP_CON")

IFS=";" read SYN_SIN SYNACK_SIN HTTP_SIN <<<"$DATA_SIN"
IFS=";" read SYN_CON SYNACK_CON HTTP_CON <<<"$DATA_CON"

echo "Escenario         | SYN | SYN-ACK | HTTP Requests"
echo "------------------|-----|---------|---------------"
echo "Sin Seguridad     | $SYN_SIN | $SYNACK_SIN | $HTTP_SIN"
echo "Con Seguridad     | $SYN_CON | $SYNACK_CON | $HTTP_CON"

echo "-------------------------------------------------------"

# 🔍 DETECCIÓN AUTOMÁTICA DE ESCENARIO

if [ "$HTTP_SIN" -lt 20 ]; then
  echo "🟡 Escenario detectado: TRÁFICO NORMAL"
  echo "Interpretación:"
  echo "- No hay suficiente tráfico para considerar un DDoS"
  echo "- Las diferencias son ruido normal de TCP"
  echo "- No se puede medir mitigación"
else
  echo "🔴 Escenario detectado: POSIBLE ATAQUE"

  if [ "$SYN_SIN" -gt 0 ]; then
    DROP=$((SYN_SIN - SYN_CON))
    EFICACIA=$(echo "scale=2; ($DROP / $SYN_SIN) * 100" | bc)
  else
    EFICACIA=0
  fi

  echo "Eficacia del sistema: $EFICACIA%"
  echo "Interpretación:"
  echo "- Reducción de SYN indica mitigación"
fi
