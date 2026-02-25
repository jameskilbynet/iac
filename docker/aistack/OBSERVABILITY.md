# Enabling Observability Stack

The observability stack (Grafana, Prometheus, OTEL Collector, Jaeger) is currently commented out due to Portainer git sync issues with config file mounts.

## Issue
Portainer's git integration doesn't properly sync config files (`prometheus/prometheus.yml`, `otel-collector-config.yaml`), causing mount failures.

## Workaround Options

### Option 1: Deploy via Portainer Web Editor
1. Copy the entire `docker-compose.yml` content
2. In Portainer, create/edit stack using "Web editor" mode (not Git)
3. Paste the compose file content
4. Deploy

### Option 2: Manual File Deployment
1. SSH to uk-bhr-p-doc-1.example.com
2. Create directory: `mkdir -p /opt/aistack/{prometheus,grafana/provisioning/datasources}`
3. Copy config files to `/opt/aistack/`
4. Update compose file to use `/opt/aistack/` paths instead of `./`
5. Deploy via Portainer

### Option 3: Use Volume Mounts
Replace file mounts with volume mounts and pre-populate the volumes with config files.

## Services Included
- **Jaeger**: https://jaeger.example.com (distributed tracing)
- **Prometheus**: https://prometheus.example.com (metrics collection)
- **Grafana**: https://grafana.example.com (dashboards)
  - Default login: admin / aistack2024 (from .env)
- **OTEL Collector**: Telemetry aggregation (ports 4317/4318)

## Current Status
Observability stack is commented out in docker-compose.yml. Uncomment lines 115-234 to enable.