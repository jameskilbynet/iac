# Cloudflare WARP Connector — Ansible Playbook

Deploys the Cloudflare WARP Connector on an Ubuntu VM, registers it with your Zero Trust organisation, and configures IP forwarding so all devices on your homelab subnet are reachable.

Inventory is managed entirely in Semaphore — the repo contains no `inventory.ini`.

## Structure

```
warp-connector/
├── deploy.yml                          # Main playbook
└── roles/
    └── warp_connector/
        ├── defaults/main.yml
        ├── handlers/main.yml
        └── tasks/main.yml
```

## Prerequisites

- Semaphore with Ansible 2.15+
- Ubuntu 22.04 or 24.04 on the target VM
- SSH access from the Semaphore runner to the target with passwordless `sudo`

## Variables

| Variable | Description |
|----------|-------------|
| `warp_connector_token` | Token from Zero Trust → Networks → WARP Connector (mark as **secret**) |

## Get your connector token

In the [Zero Trust dashboard](https://one.dash.cloudflare.com):
1. Go to **Networks → WARP Connector**
2. Select **Create connector**, give it a name
3. Copy the token shown on the next screen

## Semaphore setup

**1. Key Store** — add the SSH private key that can log in as `ubuntu@<target-ip>`.

**2. Inventory** — create a **Static** inventory named `warp-connector`:
```ini
warp-connector-01 ansible_host=192.168.4.107 ansible_user=ubuntu ansible_python_interpreter=/usr/bin/python3
```
- **User Credentials:** the SSH key from step 1
- **Sudo Credentials:** None (passwordless sudo) or a password credential

The playbook uses `hosts: all`, so any host in this inventory will be targeted.

**3. Variable Group** — create `warp-connector-vars`:
- Extra Variables (JSON):
  ```json
  { "warp_connector_token": "" }
  ```
- Add `warp_connector_token` as a **secret** with the real token value.

**4. Task Template** — `Deploy WARP Connector`:
- Playbook: `ansible/warp-connector/deploy.yml`
- Inventory: `warp-connector`
- Environment: `warp-connector-vars`

**5. Run.**

## After deployment

Back in the Zero Trust dashboard, go to **Networks → WARP Connector**, select your connector, and add a **Route** for your homelab subnet (e.g. `192.168.1.0/24`).

## Re-running (idempotent)

The playbook is safe to re-run. It checks `warp-cli status` before attempting registration or connection, so it won't re-register an already-connected connector.
