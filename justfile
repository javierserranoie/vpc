default:
    just --list

setup ISO IMG:
    VM_ISO={{ISO}} VAM_IMG={{IMG}} scripts/run-vm-bootstrap.sh

run MODE VM_IMG:
    #!/usr/bin/env bash
    case "{{ MODE }}" in
    t|terminal)
        VM_IMG={{VM_IMG}} scripts/run-vm-terminal.sh 
        ;;
    g|graphical)
        VM_IMG={{VM_IMG}} scripts/run-vm-graphical.sh 
        ;;
    v|vps)
        VM_IMG={{VM_IMG}} scripts/run-vm-vps.sh 
        ;;
    *)
        VM_IMG={{VM_IMG}} scripts/run-vm-terminal.sh 
        ;;
    esac

setup-vpc:
    scripts/setup-vpc.sh

run-vpc:
    VM_ID=1 VM_IMG=images/arch-vm1.qcow2 scripts/run-vm-vps.sh
    VM_ID=2 VM_IMG=images/arch-vm2.qcow2 scripts/run-vm-vps.sh
    VM_ID=3 VM_IMG=images/arch-vm3.qcow2 scripts/run-vm-vps.sh

stop:
    ssh root@10.100.1.30 'poweroff'
    ssh root@10.100.1.20 'poweroff'
    ssh root@10.100.1.10 'poweroff'

stop-all:
    #!/usr/bin/env bash
    kill $(pgrep qemu-system)

plan-vms:
    cd ansible && ansible-playbook playbook.yml --check --diff

configure-vms:
    cd ansible && ansible-playbook playbook.yml
