# Cloudflare WARP Connector — Ansible Playbook

Deploys the Cloudflare WARP Connector on an Ubuntu VM, registers it with your Zero Trust organisation, and configures IP forwarding so all devices on your homelab subnet are reachable.

## Structure

```
warp-connector/
├── deploy.yml                          # Main playbook
├── inventory.ini                       # Host inventory
├── group_vars/
│   └── warp_connector/
│       ├── vars.yml                    # Non-sensitive vars
│       └── vault.yml                  # Encrypted token (ansible-vault)
└── roles/
    └── warp_connector/
        ├── defaults/main.yml
        ├── handlers/main.yml
        └── tasks/main.yml
```

## Prerequisites

- Ansible 2.12+
- Ubuntu 22.04 or 24.04 target VM
- SSH access to the VM

## Setup

### 1. Get your connector token

In the [Zero Trust dashboard](https://one.dash.cloudflare.com):
1. Go to **Networks → WARP Connector**
2. Select **Create connector**, give it a name
3. Copy the token shown on the next screen

### 2. Configure inventory

Edit `inventory.ini` and replace `192.168.1.X` with your VM's IP address.

### 3. Store the token in vault

```bash
# Edit vault.yml and paste in your token
nano group_vars/warp_connector/vault.yml

# Then encrypt it
ansible-vault encrypt group_vars/warp_connector/vault.yml
```

### 4. Run the playbook

```bash
ansible-playbook -i inventory.ini deploy.yml --ask-vault-pass
```

## After deployment

Back in the Zero Trust dashboard, go to **Networks → WARP Connector**, select your connector, and add a **Route** for your homelab subnet (e.g. `192.168.1.0/24`).

## Re-running (idempotent)

The playbook is safe to re-run. It checks `warp-cli status` before attempting registration or connection, so it won't re-register an already-connected connector.
