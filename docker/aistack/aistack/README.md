# AI Stack — Ansible Deployment

Ansible playbook that provisions configuration directories on the Docker host,
copies compose and config files, and brings the stack up via `docker compose`.

Target host: `uk-bhr-p-doc-1.example.com`

---

## Prerequisites

- Ansible installed on the control machine
- SSH access to the Docker host (key-based auth, user in `inventory.yml`)
- NVIDIA Container Toolkit installed on the Docker host
- A completed `.env` file in the repo root (copy from `.env.example`)

---

## Running the playbook

All commands are run from the **repo root** (the directory containing
`docker-compose.yml`), not from this `aistack/` subdirectory.

```bash
# Full deployment — config files + containers
ansible-playbook -i aistack/aistack/inventory.yml aistack/aistack/deploy-aistack.yml

# Config files and directories only — no container restart
ansible-playbook -i aistack/aistack/inventory.yml aistack/aistack/deploy-aistack.yml --tags config

# Containers only — assumes config is already on the host
ansible-playbook -i aistack/aistack/inventory.yml aistack/aistack/deploy-aistack.yml --tags deploy

# Dry run
ansible-playbook -i aistack/aistack/inventory.yml aistack/aistack/deploy-aistack.yml --check --diff
```

### Restarting a single service after a config change

```bash
ansible-playbook -i aistack/aistack/inventory.yml aistack/aistack/deploy-aistack.yml --tags grafana
ansible-playbook -i aistack/aistack/inventory.yml aistack/aistack/deploy-aistack.yml --tags prometheus
ansible-playbook -i aistack/aistack/inventory.yml aistack/aistack/deploy-aistack.yml --tags searxng
ansible-playbook -i aistack/aistack/inventory.yml aistack/aistack/deploy-aistack.yml --tags jaeger
ansible-playbook -i aistack/aistack/inventory.yml aistack/aistack/deploy-aistack.yml --tags otel
```

---

## Running multiple instances

Each instance needs a different `AISTACK_NAMESPACE`, `DOMAIN`, and `.env` file.
Pass the namespace as an extra variable — it sets the host config directory
(`/opt/<namespace>/`), which must match `AISTACK_NAMESPACE` in the `.env`.

```bash
# Production (default)
ansible-playbook -i aistack/aistack/inventory.yml aistack/aistack/deploy-aistack.yml \
  --extra-vars "aistack_namespace=aistack aistack_env_file=.env"

# Staging
ansible-playbook -i aistack/aistack/inventory.yml aistack/aistack/deploy-aistack.yml \
  --extra-vars "aistack_namespace=aistack-staging aistack_env_file=.env.staging"

# Test (uses .env.test, which already has AISTACK_NAMESPACE=aistack-test)
ansible-playbook -i aistack/aistack/inventory.yml aistack/aistack/deploy-aistack.yml \
  --extra-vars "aistack_namespace=aistack-test aistack_env_file=.env.test"
```

The test environment host is defined in `inventory.yml` under the `test` group.
Target it with `-l docker-host-test`:

```bash
ansible-playbook -i aistack/aistack/inventory.yml aistack/aistack/deploy-aistack.yml \
  -l docker-host-test \
  --extra-vars "aistack_namespace=aistack-test aistack_env_file=.env.test"
```

---

## What the playbook does

1. Creates `/opt/<namespace>/` directory tree on the host (owner UID/GID 1000):
   ```
   /opt/<namespace>/
   ├── compose/           ← layer compose files
   ├── searxng/
   ├── jaeger/
   ├── otel-collector/
   ├── prometheus/
   └── grafana/
       └── provisioning/
           ├── datasources/
           └── dashboards/
               └── json/
   ```

2. Copies files from the git repo to the host:
   - `docker-compose.yml` (0644) — orchestrator
   - `compose/*.yml` (0644) — all 7 layer files
   - `.env` (0600 — restricted)
   - `validate-deployment.sh` (0755)
   - `searxng/settings.yml` (0644)
   - `jaeger/config.yaml` (0644)
   - `otel-collector/config.yaml` (0644)
   - `prometheus/prometheus.yml` (0644)
   - `grafana/provisioning/` tree (0644 files, 0755 dirs)

3. Ensures Docker is running and the `traefik` network exists.

4. Checks for NVIDIA GPU availability (warns if missing, does not abort).

5. Pulls latest images, then runs `docker compose up -d --remove-orphans`.

6. Waits for all services to pass health checks.

7. Creates the `langfuse` PostgreSQL database if it does not exist.

---

## Handlers

Config file changes automatically trigger a targeted container restart:

| Tag | Handler |
|---|---|
| `--tags searxng` | restarts `searxng` |
| `--tags jaeger` | restarts `jaeger` |
| `--tags otel` | restarts `otel-collector` |
| `--tags prometheus` | restarts `prometheus` |
| `--tags grafana` | restarts `grafana` |
| `--tags langfuse` | restarts `langfuse-web langfuse-worker` |