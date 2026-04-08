# AI Stack

A self-hosted AI platform built on Docker Compose. Provides local LLM inference, image generation, speech-to-text, RAG pipelines, workflow automation, LLM observability, and a full metrics/tracing stack — all behind Traefik with TLS.

---

## Services

| Layer | Service | Purpose |
|---|---|---|
| **Inference** | Ollama | LLM inference server (GPU) |
| | ComfyUI | Stable Diffusion / image generation (GPU) |
| | Whishper | Whisper speech-to-text (GPU) |
| **Interface** | Open WebUI | Chat UI — connects to all inference services |
| | Open Terminal | Browser-accessible terminal, embedded in Open WebUI |
| | Pipelines | Open WebUI middleware / Langfuse filter |
| **Routing** | SmarterRouter | Intelligent LLM routing and model selection |
| **Data** | PostgreSQL | Relational database (shared by n8n + Langfuse) |
| | Qdrant | Vector database for RAG |
| | Apache Tika | Document parsing for RAG ingestion |
| | SearxNG | Self-hosted metasearch for web RAG |
| **Langfuse** | Langfuse Web | LLM observability UI + API |
| | Langfuse Worker | Background trace processing |
| | ClickHouse | Langfuse trace analytics storage |
| | Redis | Langfuse job queue |
| | MinIO | Langfuse S3-compatible event upload storage |
| **Observability** | Jaeger | Distributed tracing backend |
| | OTel Collector | Telemetry aggregation and routing |
| | Prometheus | Metrics collection and storage |
| | Grafana | Dashboards and visualisation |
| | NVIDIA GPU Exporter | GPU metrics for Prometheus |
| **Automation** | n8n | Workflow automation and orchestration |

---

## File Structure

```
aistack/
├── docker-compose.yml          # Thin orchestrator (include directives only)
├── compose/
│   ├── inference.yml           # Ollama, ComfyUI, Whishper, MongoDB
│   ├── interface.yml           # Open WebUI, Open Terminal, Pipelines
│   ├── routing.yml             # SmarterRouter
│   ├── data.yml                # PostgreSQL, Qdrant, Tika, SearxNG
│   ├── observability.yml       # Jaeger, OTel Collector, Prometheus, Grafana
│   ├── langfuse.yml            # Langfuse + ClickHouse + Redis + MinIO
│   └── automation.yml          # n8n
├── grafana/provisioning/       # Grafana datasources and dashboard JSON
├── jaeger/config.yaml          # Jaeger storage + collector config
├── otel-collector/config.yaml  # OTel pipeline config
├── prometheus/prometheus.yml   # Scrape targets
├── searxng/settings.yml        # SearxNG engine configuration
├── aistack/
│   ├── deploy-aistack.yml      # Ansible deployment playbook
│   └── inventory.yml           # Ansible inventory
└── .env.example                # Environment variable reference
```

---

## Prerequisites

- Docker Engine 24+ with Compose v2.20+ (required for `include` support)
- NVIDIA Container Toolkit (for GPU services)
- Traefik running with a `traefik` Docker network and Cloudflare TLS resolver
- SMB/CIFS share for Prometheus and Jaeger persistent volumes (or swap to local volumes — see notes in `observability.yml`)

---

## Quick Start

```bash
# 1. Copy and fill in the environment file
cp .env.example .env
$EDITOR .env

# 2. Ensure the Traefik network exists
docker network create traefik

# 3. Deploy
docker compose up -d

# 4. Watch startup
docker compose ps
docker compose logs -f
```

Or deploy via Ansible (recommended for production). The Ansible files live in the
`aistack/` subdirectory — run all playbook commands from the **repo root** using
explicit paths to avoid confusion with the double-nesting:

```bash
# Full deploy (config files + containers)
ansible-playbook -i aistack/aistack/inventory.yml aistack/aistack/deploy-aistack.yml

# Config files only (no container restart)
ansible-playbook -i aistack/aistack/inventory.yml aistack/aistack/deploy-aistack.yml --tags config

# Containers only (config already on host)
ansible-playbook -i aistack/aistack/inventory.yml aistack/aistack/deploy-aistack.yml --tags deploy

# Deploy a second instance (different namespace, domain, and .env file)
ansible-playbook -i aistack/aistack/inventory.yml aistack/aistack/deploy-aistack.yml \
  --extra-vars "aistack_namespace=aistack-test aistack_env_file=.env.test"

# Dry run
ansible-playbook -i aistack/aistack/inventory.yml aistack/aistack/deploy-aistack.yml --check --diff
```

### Service URLs

All services are exposed at `<service>.$DOMAIN`. With `DOMAIN=example.com`:

| Service | URL |
|---|---|
| Open WebUI | `https://chat.example.com` |
| Ollama API | `https://ollama.example.com` |
| ComfyUI | `https://comfyui.example.com` |
| Whishper | `https://whishper.example.com` |
| SmarterRouter | `https://smarterrouter.example.com` |
| SearxNG | `https://searxng.example.com` |
| Langfuse | `https://langfuse.example.com` |
| n8n | `https://n8n.example.com` |
| Jaeger | `https://jaeger.example.com` |
| Prometheus | `https://prometheus.example.com` |
| Grafana | `https://grafana.example.com` |
| Open Terminal | `https://terminal.example.com` |

---

## Environment Variables

See `.env.example` for the full reference. Required variables with no default:

| Variable | Description |
|---|---|
| `DOMAIN` | Base domain, e.g. `example.com` |
| `POSTGRES_PASSWORD` | PostgreSQL password |
| `SEARXNG_SECRET` | SearxNG HMAC secret (`openssl rand -hex 32`) |
| `N8N_ENCRYPTION_KEY` | n8n encryption key (`openssl rand -hex 32`) |
| `N8N_USER_MANAGEMENT_JWT_SECRET` | n8n JWT secret (`openssl rand -hex 32`) |
| `OPEN_TERMINAL_API_KEY` | Open Terminal API key (`ot_` + `openssl rand -hex 20`) |
| `LANGFUSE_NEXTAUTH_SECRET` | Langfuse auth secret |
| `LANGFUSE_SALT` | Langfuse password salt |
| `LANGFUSE_ENCRYPTION_KEY` | Langfuse field encryption key (must be 64 hex chars) |
| `LANGFUSE_SECRET_KEY` | Langfuse API secret (create in UI after first login) |
| `LANGFUSE_PUBLIC_KEY` | Langfuse API public key (create in UI after first login) |
| `CLICKHOUSE_PASSWORD` | ClickHouse password |
| `MINIO_ROOT_PASSWORD` | MinIO root password |
| `SMB_SERVER` / `SMB_SHARE` / `SMB_USERNAME` / `SMB_PASSWORD` | SMB credentials for Prometheus and Jaeger volumes |

---

## Resource Limits

Each service has explicit `deploy.resources.limits` and `deploy.resources.reservations`. Limits are hard ceilings enforced by the Linux cgroup. Reservations influence scheduling but do not prevent a container exceeding them if the host has headroom.

### Current values (tuned for NVIDIA A10 · 24 CPU cores · 96 GB RAM)

| Service | Memory limit | CPU limit | Memory reservation | CPU reservation | GPU |
|---|---|---|---|---|---|
| **ollama** | 24 GB | 12.0 | 6 GB | 4.0 | A10 (all) |
| **comfyui** | 16 GB | 6.0 | 4 GB | 2.0 | A10 (all) |
| **whishper** | 4 GB | 4.0 | 512 MB | 0.5 | A10 (all) |
| **mongo** | 1 GB | 1.0 | 256 MB | 0.25 | — |
| **open-webui** | 2 GB | 2.0 | 512 MB | 0.5 | — |
| **pipelines** | 2 GB | 2.0 | 256 MB | 0.5 | — |
| **open-terminal** | 1 GB | 1.0 | 256 MB | 0.25 | — |
| **smarterrouter** | 2 GB | 2.0 | 256 MB | 0.5 | — |
| **postgres** | 4 GB | 4.0 | 512 MB | 1.0 | — |
| **qdrant** | 6 GB | 4.0 | 1 GB | 1.0 | — |
| **tika** | 2 GB | 2.0 | 256 MB | 0.25 | — |
| **searxng** | 1 GB | 1.0 | 128 MB | 0.25 | — |
| **jaeger** | 4 GB | 2.0 | 512 MB | 0.5 | — |
| **otel-collector** | 1 GB | 1.0 | 256 MB | 0.25 | — |
| **nvidia-gpu-exporter** | 256 MB | 0.5 | 64 MB | 0.1 | A10 (utility) |
| **prometheus** | 2 GB | 2.0 | 512 MB | 0.5 | — |
| **grafana** | 2 GB | 2.0 | 256 MB | 0.5 | — |
| **langfuse-web** | 2 GB | 2.0 | 512 MB | 0.5 | — |
| **langfuse-worker** | 2 GB | 2.0 | 512 MB | 0.5 | — |
| **clickhouse** | 6 GB | 4.0 | 1 GB | 1.0 | — |
| **redis** | 512 MB | 0.5 | 128 MB | 0.1 | — |
| **minio** | 1 GB | 1.0 | 256 MB | 0.25 | — |
| **n8n** | 4 GB | 4.0 | 512 MB | 1.0 | — |
| **Total** | **~89.75 GB** | **~61.0** | **~17 GB** | **~16.2** | |

The ~6 GB gap between total limits and host RAM is intentional — it leaves headroom for the Ubuntu host kernel, systemd, and the Docker daemon itself.

> **Note on GPU VRAM:** Docker does not enforce VRAM limits. All three GPU services share the A10's 24 GB VRAM directly via CUDA. Ollama holds models in VRAM for `OLLAMA_KEEP_ALIVE=1h`. With `OLLAMA_MAX_LOADED_MODELS=3`, typical Q4-quantised models (7B ≈ 4 GB, 13B ≈ 8 GB) sit comfortably alongside ComfyUI (SDXL ≈ 7 GB) and Whishper-small (≈ 500 MB). Running a 34B model will displace everything else — this is expected behaviour.

---

### Sizing for other hardware

The table below gives recommended limit values for three common hardware profiles. Adjust `docker-compose.yml` (or the relevant layer file) to match your setup.

**Key principles:**
- Set Ollama's memory limit to roughly match your GPU's VRAM. It needs CPU RAM for KV-cache, tokenisation, and streaming — not just for GPU offload.
- ClickHouse and Qdrant are the most memory-sensitive non-GPU services. Give them as much as you can spare; both use memory-mapped files that benefit directly from larger limits.
- CPU limits can be over-committed safely (Docker uses CFS scheduling, not pinned cores). The values here represent sensible maximums, not dedicated allocations.
- If you have no GPU, Ollama and Whishper will run on CPU. Dramatically increase Ollama's CPU limit and consider removing the `devices` reservation block from `inference.yml`.

---

#### Profile 1 — Developer laptop / low-power VM
**Target hardware:** 8–16 GB RAM · 8 CPU cores · No GPU (or consumer GPU ≤ 8 GB VRAM)

This profile runs the core inference and interface services only. Drop ComfyUI, Langfuse, and the full observability stack if RAM is tight.

| Service | Memory limit | CPU limit | Notes |
|---|---|---|---|
| ollama | 6 GB | 4.0 | CPU inference; remove `devices` block |
| comfyui | 4 GB | 2.0 | SD1.5 only; skip if < 8 GB VRAM |
| whishper | 2 GB | 2.0 | CPU inference; `tiny` model only |
| open-webui | 1 GB | 1.0 | |
| postgres | 1 GB | 2.0 | |
| qdrant | 2 GB | 2.0 | |
| prometheus | 512 MB | 1.0 | |
| grafana | 512 MB | 1.0 | |
| n8n | 1 GB | 2.0 | |
| **Total** | **~18 GB** | | Fits within 16 GB with most non-essential services stopped |

> With no GPU, set `OLLAMA_NUM_GPU=0` in `inference.yml` and remove the `devices` reservation block for ollama, comfyui, and whishper. Expect 5–15 tokens/sec on a modern CPU for 7B models.

---

#### Profile 2 — Mid-range workstation / homelab server
**Target hardware:** 32–64 GB RAM · 16 CPU cores · RTX 3090 / 4090 or equivalent (24 GB VRAM)

Consumer RTX 24 GB cards match the A10's VRAM but have lower memory bandwidth and no ECC. Slightly reduce Ollama's CPU limit relative to this stack's values since the CPU is less likely to be the bottleneck here.

| Service | Memory limit | CPU limit | Notes |
|---|---|---|---|
| ollama | 16 GB | 8.0 | |
| comfyui | 12 GB | 4.0 | SDXL supported |
| whishper | 4 GB | 2.0 | `small` or `medium` models |
| open-webui | 2 GB | 2.0 | |
| postgres | 2 GB | 2.0 | |
| qdrant | 4 GB | 2.0 | |
| clickhouse | 4 GB | 2.0 | |
| jaeger | 2 GB | 1.0 | |
| prometheus | 1 GB | 1.0 | |
| n8n | 2 GB | 2.0 | |
| **Total** | **~49 GB** | | Leaves ~12 GB for OS + other services on a 64 GB host |

---

#### Profile 3 — Current production (this stack)
**Target hardware:** 96 GB RAM · 24 CPU cores · NVIDIA A10 (24 GB VRAM)

Values as deployed — see the full table above.

---

#### Profile 4 — High-memory inference server
**Target hardware:** 192–256 GB RAM · 32–64 CPU cores · A100 80 GB or dual A10

At this scale the bottleneck shifts entirely to VRAM and GPU throughput. The infrastructure services (Postgres, Qdrant, ClickHouse) can be given generous allocations, and Ollama can load larger models (70B in Q4 ≈ 40 GB, fits on a single A100).

| Service | Memory limit | CPU limit | Notes |
|---|---|---|---|
| ollama | 48 GB | 16.0 | Supports 70B models; increase `OLLAMA_MAX_LOADED_MODELS` |
| comfyui | 24 GB | 8.0 | FLUX.1 / SDXL supported |
| whishper | 8 GB | 4.0 | `large-v3` model viable |
| open-webui | 4 GB | 4.0 | |
| postgres | 8 GB | 8.0 | |
| qdrant | 16 GB | 8.0 | Large vector collections in memory |
| clickhouse | 16 GB | 8.0 | High query throughput |
| jaeger | 8 GB | 4.0 | Long trace retention |
| prometheus | 4 GB | 4.0 | High metric cardinality |
| n8n | 8 GB | 8.0 | |
| **Total** | **~144 GB** | | Comfortable on 192 GB |

> For dual-GPU setups, set `OLLAMA_NUM_GPU=2` and adjust `count: all` in the devices block. ComfyUI can also use multi-GPU with the appropriate launch flags via `CF_EXTRA_ARGS`.

---

## Observability

### Tracing

Open WebUI emits OTLP traces to the OTel Collector, which fans them out to Jaeger. Use Jaeger UI (`https://jaeger.$DOMAIN`) to trace individual LLM requests end-to-end.

Langfuse provides LLM-specific observability: token counts, latency per model, cost tracking, and prompt history. The Langfuse filter pipeline runs inside Open WebUI Pipelines and intercepts every inference call automatically.

### Metrics

Prometheus scrapes:
- OTel Collector self-metrics
- Jaeger self-metrics
- NVIDIA GPU metrics (via `nvidia-gpu-exporter` on port 9835)
- Prometheus self-monitoring

Add scrape targets in `prometheus/prometheus.yml`. Grafana datasources are provisioned automatically from `grafana/provisioning/datasources/datasources.yaml`. Drop dashboard JSON files into `grafana/provisioning/dashboards/json/` to auto-provision them.

---

## Troubleshooting

```bash
# Check all service states
docker compose ps

# Follow logs for a specific service
docker compose logs -f ollama

# Check GPU access inside a container
docker exec aistack-ollama nvidia-smi

# Restart a single service without touching the rest
docker compose restart open-webui

# Reload config files (Prometheus, OTel Collector, Jaeger)
docker compose restart prometheus otel-collector jaeger

# Validate the compose file
docker compose config --quiet && echo "OK"
```

### Common issues

**Langfuse fails to start:** Postgres must be healthy and the `langfuse` database must exist. The Ansible playbook creates it automatically. To create it manually:
```bash
docker exec aistack-postgres psql -U $POSTGRES_USER -c "CREATE DATABASE langfuse OWNER $POSTGRES_USER;"
```

**GPU services (Ollama, ComfyUI, Whishper) fail with "no devices":** Ensure the NVIDIA Container Toolkit is installed and the Docker daemon is configured to use it:
```bash
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker
```

**OOM kills:** If a service is killed by the OOM killer, its memory limit in the relevant `compose/` layer file is too low for your workload. Increase the limit, redeploy, and monitor with `docker stats`.

---

## Security

- The Ollama API is protected by Traefik basic auth (`OLLAMA_API_CREDENTIALS`). All other services rely on Traefik TLS termination and network isolation via the `aistack-internal` bridge network (marked `internal: true` — no outbound internet access).
- The `.env` file is deployed with mode `0600` by the Ansible playbook. Never commit it to source control.
- `no-new-privileges: true` is set on all containers.
- Generate all secrets with `openssl rand -hex 32` before deploying. Do not reuse the example values.