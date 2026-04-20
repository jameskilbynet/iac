# Cloudflare WARP Connector — Ansible Playbook

Installs the Cloudflare WARP Connector on the **host it runs on**, registers it with your Zero Trust organisation, and configures IP forwarding so all devices on your homelab subnet are reachable.

The playbook runs locally (`connection: local`) — no SSH, no inventory targeting. The Semaphore runner / VM you execute this from **becomes** the WARP connector.

## Structure

```
warp-connector/
├── deploy.yml                          # Main playbook (localhost)
├── inventory.ini                       # Minimal localhost inventory
└── roles/
    └── warp_connector/
        ├── defaults/main.yml
        ├── handlers/main.yml
        └── tasks/main.yml
```

## Prerequisites

- Ansible 2.15+ installed on the target host
- Ubuntu 22.04 or 24.04
- `sudo` rights for the executing user (`become: true`)

## Variables

| Variable | Description |
|----------|-------------|
| `warp_connector_token` | Token from Zero Trust → Networks → WARP Connector (mark as **secret**) |

## Get your connector token

In the [Zero Trust dashboard](https://one.dash.cloudflare.com):
1. Go to **Networks → WARP Connector**
2. Select **Create connector**, give it a name
3. Copy the token shown on the next screen

## Usage

### With Semaphore

Run Semaphore (or a Semaphore runner) on the VM you want to become the connector.

1. Create a **Variable Group** with `warp_connector_token` (mark as secret)
2. Create an **Inventory** of type **File** pointing at `inventory.ini` (or create a static inventory containing `localhost ansible_connection=local`)
3. Create a **Task Template** with:
   - Playbook: `ansible/warp-connector/deploy.yml`
   - Inventory + Variable Group from above
   - No SSH key needed (runs locally)
4. Run the task

### Command Line (on the target host)

```bash
ansible-playbook -i inventory.ini deploy.yml \
  -e "warp_connector_token=YOUR_TOKEN"
```

## After deployment

Back in the Zero Trust dashboard, go to **Networks → WARP Connector**, select your connector, and add a **Route** for your homelab subnet (e.g. `192.168.1.0/24`).

## Re-running (idempotent)

The playbook is safe to re-run. It checks `warp-cli status` before attempting registration or connection, so it won't re-register an already-connected connector.
