# Ansible Project for VPC QEMU Configuration

This Ansible project provisions VMs using QEMU with cloud-init and applies network configurations and scripts to different VM images based on their roles.

## Project Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── inventory/
│   └── hosts.yml           # Inventory file with VM list and role fields
├── playbooks/
│   ├── main.yml            # Main configuration playbook
│   └── provision.yml       # VM provisioning playbook
└── roles/
    ├── common/             # Common configurations for all hosts
    │   ├── files/
    │   │   ├── 10-br-k8s.network
    │   │   ├── disable-swap.sh
    │   │   ├── fix_iptables.sh
    │   │   └── network.config
    │   ├── handlers/
    │   │   └── main.yml
    │   └── tasks/
    │       └── main.yml
    ├── controlplane/       # Control plane specific configurations
    │   ├── files/
    │   │   └── network-controlplane.config
    │   └── tasks/
    │       └── main.yml
    ├── kubernetes/         # Kubernetes specific configurations
    │   ├── files/
    │   │   └── network-kubernetes.config
    │   └── tasks/
    │       └── main.yml
    ├── worker/             # Worker node specific configurations
    │   ├── files/
    │   │   └── network-worker.config
    │   └── tasks/
    │       └── main.yml
    └── provision/          # VM provisioning role
        ├── defaults/
        │   └── main.yml    # Default variables
        ├── tasks/
        │   └── main.yml    # VM creation tasks
        └── templates/
            ├── user-data.j2    # Cloud-init user-data template
            └── meta-data.j2    # Cloud-init meta-data template
```

## Roles

### Provision Role
Creates and starts VMs based on the inventory:
- Generates cloud-init ISO files for each VM with hostname and SSH keys
- Creates VM disk images from the base Debian image (qcow2 format)
- Starts VMs using QEMU with proper network configuration (TAP interfaces)
- Waits for VMs to be accessible via SSH

**Prerequisites:**
- Base Debian image at `images/debian-13-generic-amd64.qcow2`
- `cloud-localds` installed for cloud-init ISO creation (from cloud-init package)
- `qemu-img` and `qemu-system-x86_64` installed
- OVMF firmware files at `/usr/share/OVMF/x64/`
- TAP interfaces created (use `scripts/setup-vpc.sh`)

**Usage:**
```bash
cd ansible
ansible-playbook playbooks/provision.yml
```

### Common Role
Applies to all hosts:
- Systemd network configuration (`10-br-k8s.network`)
- Disable swap script
- Fix iptables script
- Base network iptables rules and sysctl configuration

### Controlplane Role
Applies to control plane nodes:
- Kubernetes API server port (6443)
- etcd ports (2379-2380)
- kubelet port (10250)
- Controller-manager and scheduler ports (10257, 10259)

### Kubernetes Role
Applies to kubernetes nodes:
- Kubernetes sysctl configuration (bridge-nf-call-iptables, ip_forward)

### Worker Role
Applies to worker nodes:
- kubelet port (10250)
- kube-proxy port (10256)
- NodePort Services ports (30000-32767)

## Usage

### Provisioning VMs

Before configuring VMs, you need to provision them:

```bash
# Ensure VPC network is set up
../scripts/setup-vpc.sh

# Provision all VMs from inventory
cd ansible
ansible-playbook playbooks/provision.yml
```

This will:
1. Create cloud-init ISO files for each VM in the inventory
2. Create VM disk images from the base Debian image
3. Start all VMs with QEMU
4. Wait for VMs to be accessible via SSH

### Running the configuration playbook

```bash
cd ansible
ansible-playbook playbooks/main.yml
```

### Running against specific hosts

The playbook automatically applies role-specific configurations based on the `role` field in the inventory. To limit execution to specific hosts:

```bash
# Apply to a specific host
ansible-playbook playbooks/main.yml --limit node-1

# Apply to multiple specific hosts
ansible-playbook playbooks/main.yml --limit node-1,node-2
```

Note: Role-specific configurations (controlplane, kubernetes, worker) are automatically applied based on each host's `role` field, so you don't need to filter by role manually.

### Customizing the inventory

Edit `inventory/hosts.yml` to match your actual host IPs and VM IDs. The inventory uses a flat structure where each VM has:
- `ansible_host`: IP address of the VM
- `vm_id`: Unique ID for the VM (used in network configuration)
- `role`: Role of the VM (`controlplane` or `worker`)

Example:
```yaml
node-1:
  ansible_host: 10.100.1.10
  vm_id: 1
  role: controlplane
```

## Requirements

### For VM Provisioning
- Ansible 2.9 or higher
- QEMU/KVM installed (`qemu-system-x86_64`, `qemu-img`)
- `genisoimage` or `mkisofs` for cloud-init ISO creation
- OVMF firmware files (`/usr/share/OVMF/x64/OVMF_CODE.4m.fd` and `OVMF_VARS.4m.fd`)
- Base Debian image at `images/debian-13-generic-amd64.qcow2`
- TAP interfaces set up (run `scripts/setup-vpc.sh` first)
- SSH public key at `~/.ssh/id_rsa.pub` (or set `ansible_ssh_public_key_file`)

### For VM Configuration
- Python 3 on target hosts
- SSH access to target hosts with sudo privileges
- iptables and systemd-networkd on target hosts

## Notes

- The playbook requires root privileges (become: yes)
- Network configuration uses VM_ID variable for IP assignment (10.100.1.${VM_ID}0/24)
- Scripts are copied to `/usr/local/bin` and executed
- iptables rules are saved and enabled as a service
