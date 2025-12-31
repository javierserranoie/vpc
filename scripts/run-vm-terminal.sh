#!/usr/bin/env bash
# qemu-img create -f qcow2 -F qcow2 -b arch.qcow2 arch-vm1.qcow2
set -euo pipefail

VM_ID="${VM_ID:-1}"
VM_IMG="${VM_IMG:-images/linux-$VM_ID.qcow2}"
VM_PORT=$(printf '%02u' "$VM_ID")
MAC_SUFFIX=$(printf '%02x' "$VM_ID")
VM_MAC="52:54:00:12:34:${MAC_SUFFIX}"
VM_SIZE=${VM_SIZE:-25G}

OVMF_CODE=/usr/share/OVMF/x64/OVMF_CODE.4m.fd
OVMF_VARS=$HOME/workspace/personal/vpc-qemu/OVMF_VARS.4m.fd

[ ! -f "$OVMF_VARS" ] && cp /usr/share/OVMF/x64/OVMF_VARS.4m.fd "$OVMF_VARS"

qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp sockets=1,cores=4,threads=1 \
    -m size=4G,slots=2,maxmem=8G \
    -blockdev node-name=ovmf_code_file,driver=file,filename="$OVMF_CODE",read-only=on \
    -blockdev node-name=ovmf_code,driver=raw,file=ovmf_code_file,read-only=on \
    -blockdev node-name=ovmf_vars_file,driver=file,filename="$OVMF_VARS" \
    -blockdev node-name=ovmf_vars,driver=raw,file=ovmf_vars_file \
    -machine q35,accel=kvm,pflash0=ovmf_code,pflash1=ovmf_vars \
    -blockdev driver=file,filename=${VM_IMG},node-name=drive0_file \
    -blockdev driver=qcow2,file=drive0_file,node-name=drive0_qcow2 \
    -device virtio-blk-pci,drive=drive0_qcow2,bootindex=1 \
    -netdev user,id=nic${VM_ID},hostfwd=tcp::22${VM_PORT}-:22 \
    -device virtio-net,netdev=nic${VM_ID},mac="${VM_MAC}" \
    -daemonize -display none
