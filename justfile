default:
    just --list

setup:
    scripts/setup-k8s-vpc.sh

run VM_ID:
    VM_ID={{VM_ID}} scripts/run-vm-no-ssh.sh 

setup-vm VM_ID:
    VM_ID={{VM_ID}} scripts/run-vm-setup.sh
    VM_ID={{VM_ID}} scripts/network-setup.sh

run-k8s:
    VM_ID=1 scripts/run-vm-ssh.sh
    VM_ID=2 scripts/run-vm-ssh.sh
    VM_ID=3 scripts/run-vm-ssh.sh
    sleep 30
    scp ./configuration/*.config js@10.100.1.10:~/
    scp ./configuration/*.config js@10.100.1.20:~/
    scp ./configuration/*.config js@10.100.1.30:~/
    scp ./configuration/*.ssh js@10.100.1.10:~/
    scp ./configuration/*.ssh js@10.100.1.20:~/
    scp ./configuration/*.ssh js@10.100.1.30:~/

run-no-ssh VM_ID:
    VM_ID={{VM_ID}} scripts/run-vm-no-ssh.sh 

run-ssh VM_ID:
    VM_ID={{VM_ID}} scripts/run-vm-ssh.sh 

stop-all:
    #!/usr/bin/env bash
    kill $(pgrep qemu-system)
