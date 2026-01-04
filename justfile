default:
    just --list

setup ISO IMG="./images/linux.qcow2":
    ISO={{ISO}} VM_IMG={{IMG}} scripts/run-vm-bootstrap.sh

# Run VM with the new simplified script
# Usage: just run [options] <image.qcow2> [VM_ID]
# Options (must come before image):
#   -t  Terminal/nographic mode
#   -g  Graphical mode (default)
#   -c  Skip cloud-init ISO
# Arguments:
#   image.qcow2  Path to VM disk image (required)
#   VM_ID        VM ID number (default: 1)
# Examples:
#   just run images/node-1.qcow2
#   just run -t images/node-1.qcow2
#   just run -t images/node-1.qcow2 2
#   just run -c images/node-1.qcow2
#   just run -t -c images/node-1.qcow2 3
run *ARGS:
    scripts/run-vm.sh {{ARGS}}

setup-vpc:
    scripts/setup-vpc.sh

run-vpc:
    scripts/run-vm-vps.sh images/node-1.qcow2 1
    scripts/run-vm-vps.sh images/node-2.qcow2 2
    #scripts/run-vm-vps.sh images/node-3.qcow2 3

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

# Setup/provision VMs using Ansible
setup-vm:
    cd ansible && ansible-playbook playbooks/provision.yml

configure-vm:
    cd ansible && ansible-playbook playbooks/main.yml

# Clean up all VM-related files created by Ansible
clean-vm:
    scripts/clean-vms.sh
