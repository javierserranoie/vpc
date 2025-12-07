#!/usr/bin/env bash
set -e

echo "==> Desactivando swap activo (si existe)..."
if grep -q zram /proc/swaps; then
    for dev in $(awk '/zram/ {print $1}' /proc/swaps); do
        echo "    swapoff $dev"
        swapoff "$dev" || true
    done
else
    echo "    No hay swap zram activo"
fi

echo "==> Enmascarando servicios relacionados con zram..."
for unit in \
    systemd-zram-setup@.service \
    systemd-zram-setup@zram0.service \
    zramd.service \
    systemd-swap.service; do
    if systemctl list-unit-files | grep -q "^$unit"; then
        echo "    mask $unit"
        systemctl mask "$unit" || true
    fi
done

echo "==> Eliminando configuraciones de zram-generator..."
rm -f /etc/systemd/zram-generator.conf
rm -f /usr/lib/systemd/zram-generator.conf

echo "==> Recargando systemd..."
systemctl daemon-reexec
systemctl daemon-reload

echo "==> Verificando estado final..."
cat /proc/swaps || true

echo
echo "✅ ZRAM desactivado permanentemente."
echo "   Reinicia el sistema para asegurarlo al 100%."
