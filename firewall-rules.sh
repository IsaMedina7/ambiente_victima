#!/bin/sh

echo "[*] Iniciando configuración del firewall GAIA..."

echo 1 >/proc/sys/net/ipv4/ip_forward
echo "[✓] IP Forwarding habilitado"

# --- LIMPIAR REGLAS PREVIAS ---
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# --- POLÍTICAS POR DEFECTO (DENY ALL) ---
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# ============================================================
# 1. LOOPBACK (CRÍTICO)
# ============================================================
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# ============================================================
# 2. CONEXIONES ESTABLECIDAS
# ============================================================
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ============================================================
# 3. TRÁFICO EXTERNO (ACCESO PÚBLICO)
# ============================================================

# Permitir tráfico HTTP/HTTPS desde cualquier lugar hacia el firewall
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Permitir tráfico SSH (opcional)
iptables -A INPUT -p tcp --dport 2222 -j ACCEPT

# ============================================================
# 4. TRÁFICO DMZ (10.5.0.0/24)
# ============================================================
iptables -A FORWARD -s 10.5.0.0/24 -d 10.5.0.0/24 -j ACCEPT
iptables -A INPUT -s 10.5.0.0/24 -d 10.5.0.5 -j ACCEPT

# Honeypot (10.5.0.20) → ACEPTAR TODO
iptables -A FORWARD -s 10.5.0.20 -j ACCEPT
iptables -A FORWARD -d 10.5.0.20 -j ACCEPT

# App Flask (10.5.0.50) → Permitir puerto 5000
iptables -A FORWARD -s 10.5.0.50 -p tcp --dport 5000 -j ACCEPT
iptables -A FORWARD -d 10.5.0.50 -p tcp --sport 5000 -j ACCEPT

# IMPORTANTE: También debes permitir el paso en la cadena FORWARD (Sección 4)
iptables -A FORWARD -p tcp -d 10.5.0.50 --dport 5000 -j ACCEPT

# ============================================================
# 5. TRÁFICO DESDE EXTERNO HACIA INTERNAL (PROTEGIDO)
# ============================================================

# Solo HTTP/HTTPS hacia Apache (10.6.0.10)
iptables -A FORWARD -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -p tcp --dport 443 -j ACCEPT

# Respuestas de Apache hacia externo
iptables -A FORWARD -s 10.6.0.10 -p tcp --sport 80 -j ACCEPT
iptables -A FORWARD -s 10.6.0.10 -p tcp --sport 443 -j ACCEPT

# ============================================================
# 6. MITIGACIÓN DDoS - SYN FLOOD
# ============================================================
iptables -A FORWARD -p tcp --syn -m limit --limit 25/second --limit-burst 50 -j ACCEPT
iptables -A FORWARD -p tcp --syn -j DROP

iptables -A INPUT -p tcp --syn -m limit --limit 25/second --limit-burst 50 -j ACCEPT
iptables -A INPUT -p tcp --syn -j DROP

# ============================================================
# 7. MITIGACIÓN DDoS - SLOWLORIS
# ============================================================
iptables -A FORWARD -p tcp --dport 80 -m connlimit --connlimit-above 30 -j REJECT --reject-with tcp-reset
iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 30 -j REJECT --reject-with tcp-reset

# ============================================================
# 8. MITIGACIÓN DDoS - ICMP FLOOD
# ============================================================
iptables -A FORWARD -p icmp --icmp-type echo-request -m limit --limit 10/second --limit-burst 20 -j ACCEPT
iptables -A FORWARD -p icmp --icmp-type echo-request -j DROP

iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 10/second --limit-burst 20 -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

# Permitir respuestas ICMP
iptables -A FORWARD -p icmp --icmp-type echo-reply -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT

# ============================================================
# 9. NAT - REDIRECCIÓN DE PUERTOS
# ============================================================

# Puerto 80 (externo) → 10.6.0.10:80 (Apache)
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 10.6.0.10:80
iptables -t nat -A POSTROUTING -d 10.6.0.10 -p tcp --dport 80 -j MASQUERADE

# Puerto 443 (externo) → 10.6.0.10:443 (Apache)
iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination 10.6.0.10:443
iptables -t nat -A POSTROUTING -d 10.6.0.10 -p tcp --dport 443 -j MASQUERADE

# Puerto 5000 (externo) → 10.5.0.50:5000 (App IDS)
iptables -t nat -A PREROUTING -p tcp --dport 5000 -j DNAT --to-destination 10.5.0.50:5000
iptables -t nat -A POSTROUTING -d 10.5.0.50 -p tcp --dport 5000 -j MASQUERADE

# ============================================================
# 10. REGLA FINAL
# ============================================================
iptables -A FORWARD -j DROP
iptables -A INPUT -j DROP

echo "[✓] Firewall con mitigación DDoS iniciado correctamente"
echo "[✓] IP Forwarding: $(cat /proc/sys/net/ipv4/ip_forward)"
echo ""
echo "[✓] Reglas activas:"
iptables -L -n -v | head -30
echo ""
echo "[✓] Reglas NAT:"
iptables -t nat -L -n -v
echo ""
echo "[*] Firewall en espera..."

tail -f /dev/null
