# AI Stack Ansible Deployment

Ansible playbook to consistently deploy the AI stack to `uk-bhr-p-doc-1.jameskilby.cloud`.

## Prerequisites

- Ansible installed on the control machine
- SSH access to the Docker host (key-based auth)
- NVIDIA Container Toolkit installed on the Docker host

## Usage

### Full deployment (config + deploy)

```bash
ansible-playbook -i inventory.yml deploy-aistack.yml
```

### Config files and directories only (no container restart)

```bash
ansible-playbook -i inventory.yml deploy-aistack.yml --tags config
```

### Deploy/restart containers only (assumes config is already in place)

```bash
ansible-playbook -i inventory.yml deploy-aistack.yml --tags deploy
```

### Update a single service config

```bash
ansible-playbook -i inventory.yml deploy-aistack.yml --tags grafana
ansible-playbook -i inventory.yml deploy-aistack.yml --tags prometheus
ansible-playbook -i inventory.yml deploy-aistack.yml --tags searxng
ansible-playbook -i inventory.yml deploy-aistack.yml --tags jaeger
ansible-playbook -i inventory.yml deploy-aistack.yml --tags otel
```

### Dry run

```bash
ansible-playbook -i inventory.yml deploy-aistack.yml --check --diff
```

## What it does

1. Creates `/opt/aistack/` directory tree with correct ownership (UID/GID 1000)
2. Copies all configuration files from the git repo to the host:
   - `docker-compose.yml` (0644)
   - `.env` (0600 — restricted)
   - `validate-deployment.sh` (0755)
   - `searxng/settings.yml` (0644)
   - `jaeger/config.yaml` (0644)
   - `otel-collector/config.yaml` (0644)
   - `prometheus/prometheus.yml` (0644)
   - `grafana/provisioning/` tree (0644 files, 0755 dirs)
3. Ensures Docker is running and the `traefik` network exists
4. Checks for NVIDIA GPU availability
5. Pulls images and deploys the stack via `docker compose up -d`
6. Waits for services to pass health checks

## Handlers

Config file changes automatically trigger a restart of the affected container (searxng, jaeger, otel-collector, prometheus, grafana).
