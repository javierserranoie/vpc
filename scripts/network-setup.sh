#!/usr/bin/env bash

set -a
VM_ID=${VM_ID:-1}

TMP_FILE=10-br-k8s-$(openssl rand -hex 3).network

ssh -p 2222 js@localhost "echo '$(cat ~/.ssh/id_ed25519.pub)' >> ~/.ssh/authorized_keys"

envsubst <configuration/10-br-k8s.network >$TMP_FILE &&
    scp -P 2222 $TMP_FILE js@localhost:~/ &&
    ssh -t -p 2222 js@localhost "sudo mv ~/$TMP_FILE /etc/systemd/network/" &&
    rm $TMP_FILE

set +a
