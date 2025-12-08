default:
    just --list

setup:
    scripts/setup-vpc.sh

run VM_ID MODE:
    case "{{ MODE }}" in
    terminal)
        VM_ID={{VM_ID}} scripts/run-vm-terminal.sh 
        ;;
    graphical)
        VM_ID={{VM_ID}} scripts/run-vm-graphical.sh 
        ;;
    vps)
        VM_ID={{VM_ID}} scripts/run-vm-vps.sh 
        ;;
    *)
        VM_ID={{VM_ID}} scripts/run-vm-terminal.sh 
        ;;
    esac

setup VM_ID:
    VM_ID={{VM_ID}} scripts/run-vm-setup.sh
    VM_ID={{VM_ID}} scripts/network-setup.sh

run-vpc:
    VM_ID=1 scripts/run-vm-vps.sh
    VM_ID=2 scripts/run-vm-vps.sh
    VM_ID=3 scripts/run-vm-vps.sh

stop-all:
    #!/usr/bin/env bash
    kill $(pgrep qemu-system)
