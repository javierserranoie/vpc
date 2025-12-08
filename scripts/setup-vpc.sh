#!/usr/bin/env bash
set -euo pipefail

# Configuración básica
BRIDGE="br-k8s"
BRIDGE_CIDR="10.100.1.1/24"
SUBNET_CIDR="10.100.1.0/24"
TAPS=("tap-k8s1" "tap-k8s2" "tap-k8s3")

# Detectar interfaz WAN (puerta de salida a Internet)
WAN_DEV="${WAN_DEV:-$(ip route | awk '/^default/ {print $5; exit}')}"
if [[ -z "${WAN_DEV}" ]]; then
  echo "No se pudo detectar interfaz WAN (default route). Exporta WAN_DEV=eth0 (o similar) y reintenta."
  exit 1
fi

echo "Usando interfaz WAN: ${WAN_DEV}"

# 1. Crear bridge si no existe
if ! ip link show "${BRIDGE}" &>/dev/null; then
  echo "Creando bridge ${BRIDGE}..."
  sudo ip link add "${BRIDGE}" type bridge
else
  echo "Bridge ${BRIDGE} ya existe, continuando..."
fi

# 2. Asignar IP al bridge si no la tiene
if ! ip addr show dev "${BRIDGE}" | grep -q "${BRIDGE_CIDR%/*}"; then
  echo "Asignando IP ${BRIDGE_CIDR} a ${BRIDGE}..."
  sudo ip addr add "${BRIDGE_CIDR}" dev "${BRIDGE}"
fi

# Levantar el bridge
sudo ip link set "${BRIDGE}" up

# 3. Crear TAPs y añadirlos al bridge
RUN_USER="${SUDO_USER:-$USER}"

for TAP in "${TAPS[@]}"; do
  if ! ip link show "${TAP}" &>/dev/null; then
    echo "Creando interfaz TAP ${TAP} para usuario ${RUN_USER}..."
    sudo ip tuntap add "${TAP}" mode tap user "${RUN_USER}"
  else
    echo "TAP ${TAP} ya existe, continuando..."
  fi

  # Asociar al bridge y levantar
  sudo ip link set "${TAP}" master "${BRIDGE}" || true
  sudo ip link set "${TAP}" up
done

# 4. Habilitar IP forwarding
echo "Habilitando IPv4 forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null

# 5. Reglas iptables (NAT + FORWARD) solo para 10.100.1.0/24

echo "Configurando iptables (NAT + FORWARD para ${SUBNET_CIDR} -> ${WAN_DEV})..."

# NAT: POSTROUTING
if ! sudo iptables -t nat -C POSTROUTING -s "${SUBNET_CIDR}" -o "${WAN_DEV}" -j MASQUERADE 2>/dev/null; then
  sudo iptables -t nat -A POSTROUTING -s "${SUBNET_CIDR}" -o "${WAN_DEV}" -j MASQUERADE
fi

# FORWARD: desde bridge hacia WAN
if ! sudo iptables -C FORWARD -i "${BRIDGE}" -o "${WAN_DEV}" -j ACCEPT 2>/dev/null; then
  sudo iptables -A FORWARD -i "${BRIDGE}" -o "${WAN_DEV}" -j ACCEPT
fi

# FORWARD: tráfico de retorno hacia bridge (solo conexiones establecidas)
if ! sudo iptables -C FORWARD -i "${WAN_DEV}" -o "${BRIDGE}" -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; then
  sudo iptables -A FORWARD -i "${WAN_DEV}" -o "${BRIDGE}" -m state --state ESTABLISHED,RELATED -j ACCEPT
fi

echo "Listo."
echo "Bridge: ${BRIDGE} (${BRIDGE_CIDR})"
echo "TAPs: ${TAPS[*]}"
echo "Subred VPC: ${SUBNET_CIDR}"
echo "Las VMs deberán usar gateway 10.100.1.1"

