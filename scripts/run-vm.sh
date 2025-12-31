#!/usr/bin/env bash
# Simple script to run a QEMU VM from a qcow2 image
# Usage: ./run-vm.sh [image.qcow2] [options]
#   Options:
#     --graphical    : Use graphical display (default)
#     --terminal     : Use terminal display
#     --no-cloudinit: Skip cloud-init ISO attachment

set -euo pipefail

# Default values
VM_IMG=""
VM_ID="${VM_ID:-1}"
DISPLAY_MODE="${DISPLAY_MODE:-graphical}"
ATTACH_CLOUDINIT="${ATTACH_CLOUDINIT:-true}"

# Parse options first (must come before image path)
while [[ $# -gt 0 && $1 =~ ^- ]]; do
    case $1 in
        -g|--graphical)
            DISPLAY_MODE="graphical"
            shift
            ;;
        -t|--terminal)
            DISPLAY_MODE="terminal"
            shift
            ;;
        -c|--no-cloudinit)
            ATTACH_CLOUDINIT="false"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options] <image.qcow2> [VM_ID]"
            echo ""
            echo "Options (must come before image path):"
            echo "  -g, --graphical      Use graphical display (default)"
            echo "  -t, --terminal       Use terminal/nographic mode"
            echo "  -c, --no-cloudinit   Skip attaching cloud-init ISO"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "Arguments:"
            echo "  image.qcow2          Path to the VM disk image (required)"
            echo "  VM_ID                VM ID number (default: 1)"
            echo ""
            echo "Examples:"
            echo "  $0 images/node-1.qcow2"
            echo "  $0 -t images/node-1.qcow2"
            echo "  $0 -t images/node-1.qcow2 2"
            echo "  $0 -c images/node-1.qcow2"
            echo "  $0 -t -c images/node-1.qcow2 3"
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# First remaining argument is the image path
if [[ $# -eq 0 ]]; then
    echo "Error: Image path is required"
    echo "Use -h or --help for usage information"
    exit 1
fi

VM_IMG="$1"
shift

# Second remaining argument (if any) is VM_ID
if [[ $# -gt 0 ]]; then
    VM_ID="$1"
    shift
fi

# Check for extra arguments
if [[ $# -gt 0 ]]; then
    echo "Error: Unexpected arguments: $*"
    echo "Use -h or --help for usage information"
    exit 1
fi

# VM_ID is already set above, no need to check here

# Resolve absolute path
if [[ ! "$VM_IMG" =~ ^/ ]]; then
    VM_IMG="$(realpath "$VM_IMG")"
fi

# Check if image exists
if [[ ! -f "$VM_IMG" ]]; then
    echo "Error: Image file not found: $VM_IMG"
    exit 1
fi

# Extract VM name from image path (e.g., images/node-1.qcow2 -> node-1)
# Use VM_ID if provided, otherwise try to extract from filename
VM_NAME=$(basename "$VM_IMG" .qcow2)
PROJECT_ROOT=$(dirname "$(dirname "$VM_IMG")")

# OVMF paths
OVMF_CODE="/usr/share/OVMF/x64/OVMF_CODE.4m.fd"
OVMF_VARS_DIR="${PROJECT_ROOT}/ovmf_vars"
OVMF_VARS="${OVMF_VARS_DIR}/OVMF_VARS_${VM_NAME}.4m.fd"

# Cloud-init paths
CLOUDINIT_DIR="${PROJECT_ROOT}/cloudinit/vms"
CLOUDINIT_ISO="${CLOUDINIT_DIR}/${VM_NAME}-cloud-init.iso"

# Create OVMF vars directory if needed
mkdir -p "$OVMF_VARS_DIR"

# Copy OVMF vars if it doesn't exist
if [[ ! -f "$OVMF_VARS" ]]; then
    if [[ -f "/usr/share/OVMF/x64/OVMF_VARS.4m.fd" ]]; then
        cp /usr/share/OVMF/x64/OVMF_VARS.4m.fd "$OVMF_VARS"
        echo "Created OVMF vars file: $OVMF_VARS"
    else
        echo "Warning: OVMF_VARS.4m.fd not found at /usr/share/OVMF/x64/"
    fi
fi

# Build QEMU command
QEMU_CMD=(
    qemu-system-x86_64
    -enable-kvm
    -cpu host
    -smp sockets=1,cores=2,threads=1
    -m size=4G,slots=2,maxmem=8G
    -blockdev "node-name=ovmf_code_file,driver=file,filename=${OVMF_CODE},read-only=on"
    -blockdev "node-name=ovmf_code,driver=raw,file=ovmf_code_file,read-only=on"
    -blockdev "node-name=ovmf_vars_file,driver=file,filename=${OVMF_VARS}"
    -blockdev "node-name=ovmf_vars,driver=raw,file=ovmf_vars_file"
    -machine "q35,accel=kvm,pflash0=ovmf_code,pflash1=ovmf_vars"
    -blockdev "driver=file,filename=${VM_IMG},node-name=drive0_file"
    -blockdev "driver=qcow2,file=drive0_file,node-name=drive0_qcow2"
    -device "virtio-blk-pci,drive=drive0_qcow2,bootindex=1"
)

# Attach cloud-init ISO if requested and exists
if [[ "$ATTACH_CLOUDINIT" == "true" && -f "$CLOUDINIT_ISO" ]]; then
    echo "Attaching cloud-init ISO: $CLOUDINIT_ISO"
    QEMU_CMD+=(
        -blockdev "driver=file,filename=${CLOUDINIT_ISO},read-only=on,node-name=ci_file"
        -blockdev "driver=raw,file=ci_file,node-name=ci_raw"
        -device "ide-cd,drive=ci_raw"
    )
elif [[ "$ATTACH_CLOUDINIT" == "true" ]]; then
    echo "Warning: Cloud-init ISO not found: $CLOUDINIT_ISO"
    echo "         Continuing without cloud-init..."
fi

# Add network (user mode networking for simplicity)
# Calculate MAC address and SSH port based on VM_ID
MAC_SUFFIX=$(printf '%02x' "$VM_ID")
VM_MAC="52:54:00:12:34:${MAC_SUFFIX}"
SSH_PORT=$((2220 + VM_ID))

QEMU_CMD+=(
    -netdev "user,id=nic0,hostfwd=tcp::${SSH_PORT}-:22"
    -device "virtio-net,netdev=nic0,mac=${VM_MAC}"
)

# Set display mode
if [[ "$DISPLAY_MODE" == "terminal" ]]; then
    QEMU_CMD+=(-nographic)
else
    QEMU_CMD+=(-display gtk)
fi

# Add VM name
QEMU_CMD+=(-name "$VM_NAME")

echo "Starting VM: $VM_NAME"
echo "Image: $VM_IMG"
echo "Command: ${QEMU_CMD[*]}"
echo ""

# Run QEMU
exec "${QEMU_CMD[@]}"
