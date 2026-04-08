# AI Stack Ansible Deployment

Ansible playbook to deploy the AI stack to one or more Docker hosts. Supports multiple named environments (e.g. `aistack`, `aistack-test`) on the same or different hosts via `aistack_namespace`.

## Prerequisites

- Ansible installed on the control machine
- SSH access to the Docker host (key-based auth)
- NVIDIA Container Toolkit installed on the Docker host

## Environments

| Environment | Host | Namespace |
|-------------|------|-----------|
| Production | `uk-bhr-p-doc-1.jameskilby.cloud` | `aistack` |
| Test | `blogtest.jameskilby.cloud` | `aistack-test` |

Each environment deploys to `/opt/<namespace>/` and runs as a separate Docker Compose project, so both can coexist on the same host.

## Usage

Use `run.sh` — it resolves its own directory so it works from anywhere in the repo:

```bash
# From repo root
./ansible/docker/stacks/aistack/run.sh

# From this directory
./run.sh

# With flags — all extra args are passed through
./run.sh --limit test
./run.sh --tags config
./run.sh --tags deploy
./run.sh --check --diff
./run.sh --extra-vars "aistack_namespace=aistack-dev aistack_env_file=.env.dev"
```

### Common operations

| Goal | Command |
|------|---------|
| Full deploy (production) | `./run.sh` |
| Full deploy (test) | `./run.sh --limit test` |
| Config files only, no restart | `./run.sh --tags config` |
| Containers only (config already in place) | `./run.sh --tags deploy` |
| Single service config | `./run.sh --tags grafana` |
| Dry run | `./run.sh --check --diff` |

### Semaphore

Set the task template **Playbook Filename** to:

```
ansible/docker/stacks/aistack/deploy-aistack.yml
```

And **Inventory** to file path:

```
ansible/docker/stacks/aistack/inventory.yml
```

Semaphore passes the inventory and playbook as absolute paths so no wrapper is needed.

## Semaphore

Create an **Environment** in Semaphore with the following Extra Variables (JSON), filling in real values:

```json
{
  "OLLAMA_API_CREDENTIALS": "",
  "OLLAMA_BASE_URL": "",
  "INFERENCE_TEXT_MODEL": "llama3.1:8b",
  "INFERENCE_IMAGE_MODEL": "llava",
  "DB_USER": "",
  "DB_PASS": "",
  "WHISHPER_HOST": "",
  "WHISPER_MODELS": "tiny,small",
  "PUID": "1000",
  "PGID": "1000",
  "MEILI_ADDR": "http://meilisearch:7700",
  "MEILI_MASTER_KEY": "",
  "NEXTAUTH_URL": "",
  "HOARDER_VERSION": "release",
  "NEXTAUTH_SECRET": "",
  "GRAFANA_USER": "",
  "GRAFANA_ADMIN_PASSWORD": "",
  "OTEL_ENVIRONMENT": "homelab",
  "OTEL_CLUSTER": "aistack",
  "OTEL_COLLECTOR_ENDPOINT": "http://otel-collector:4318",
  "JAEGER_STORAGE_TYPE": "badger",
  "JAEGER_BADGER_EPHEMERAL": "false",
  "JAEGER_BADGER_CONSISTENCY": "true",
  "SMB_SERVER": "",
  "SMB_SHARE": "",
  "SMB_USERNAME": "",
  "SMB_PASSWORD": "",
  "POSTGRES_DB": "aistack",
  "POSTGRES_USER": "",
  "POSTGRES_PASSWORD": "",
  "SEARXNG_SECRET": "",
  "N8N_ENCRYPTION_KEY": "",
  "N8N_USER_MANAGEMENT_JWT_SECRET": "",
  "OPEN_TERMINAL_API_KEY": "",
  "BACKUP_RETENTION_DAYS": "7",
  "BACKUP_COMPRESS": "true"
}
```

The playbook writes these directly to `/opt/<namespace>/.env` on the host — no `.env` file needs to exist in the repo.

## What it does

1. Creates `/opt/<namespace>/` directory tree with correct ownership (UID/GID 1000)
2. Writes `.env` to the host — from `aistack_env_file` if set, otherwise from Semaphore extra vars
3. Copies all configuration files from the repo:
   - `docker-compose.yml` (0644)
   - `validate-deployment.sh` (0755)
   - `searxng/settings.yml` (0644)
   - `jaeger/config.yaml` (0644)
   - `otel-collector/config.yaml` (0644)
   - `prometheus/prometheus.yml` (0644)
   - `grafana/provisioning/` tree (0644 files, 0755 dirs)
4. Ensures Docker is running and the `traefik` network exists
5. Warns if NVIDIA GPU is unavailable
6. Pulls images and deploys via `docker compose --project-name <namespace> up -d`
7. Waits for services to pass health checks
8. Creates the `langfuse` PostgreSQL database if it doesn't exist

## Handlers

Config file changes automatically trigger a restart of the affected container: `searxng`, `jaeger`, `otel-collector`, `prometheus`, `grafana`, `langfuse-web`, `langfuse-worker`.
