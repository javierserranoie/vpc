#!/usr/bin/env bash
# qemu-img create -f qcow2 -F qcow2 -b arch.qcow2 arch-vm1.qcow2
set -euo pipefail

VM_ID="${VM_ID:-1}"
VM_IMG="${VM_IMG:-1images/arch-vm$VM_ID.qcow2}"

MAC_SUFFIX=$(printf '%02x' "$VM_ID")
VM_MAC="52:54:00:12:34:${MAC_SUFFIX}"

qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -m 7632 \
    -smp cpus=2,sockets=1,cores=2,threads=1 \
    -drive file=${VM_IMG},if=virtio,format=qcow2 \
    -netdev user,id=n${VM_ID},hostfwd=tcp::2222-:22 \
    -device virtio-net,netdev=n${VM_ID},mac="${VM_MAC}" \
    -daemonize -display none
