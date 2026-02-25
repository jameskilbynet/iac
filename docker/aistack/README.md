# AI Stack with OpenTelemetry Observability

This Docker Compose configuration provides a complete AI stack with comprehensive observability using OpenTelemetry, Jaeger, Prometheus, and Grafana.

## Services

### AI Stack
- **Ollama**: Local LLM server with GPU acceleration
- **Open WebUI**: Modern chat interface for Ollama
- **SearxNG**: Privacy-focused search engine for RAG
- **Hoarder**: Bookmark and content management

### Observability Stack
- **OpenTelemetry Collector**: Centralized telemetry collection and processing
- **Jaeger**: Distributed tracing backend
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards

## Quick Start

1. **Prerequisites**:
   ```bash
   # Ensure Traefik is running
   cd ../traefik && docker compose up -d
   
   # Create traefik network if it doesn't exist
   docker network create traefik
   ```

2. **Generate required secrets**:
   ```bash
   # Generate Meili and NextAuth secrets
   openssl rand -base64 36
   ```
   Update the `.env` file with the generated secrets.

3. **Deploy the stack**:
   ```bash
   docker compose up -d
   ```

4. **Access the services**:
   - Chat Interface: https://chat.example.com
   - Ollama API: https://ollama.example.com
   - Jaeger Tracing: https://jaeger.example.com
   - Prometheus: https://aistack-prometheus.example.com
   - Grafana: https://aistack-grafana.example.com (admin/aistack2024)
   - Hoarder: https://hoarder.example.com

## OpenTelemetry Configuration

### Tracing
All services are configured to send traces to the OpenTelemetry Collector, which forwards them to Jaeger. This provides:

- **Request tracing**: Track requests across Ollama and Open WebUI
- **Performance monitoring**: Identify bottlenecks and latency issues
- **Error tracking**: Capture and analyze failed requests

### Metrics
Prometheus collects metrics from:
- OpenTelemetry Collector
- Jaeger
- Container metrics (if cAdvisor is available)
- Custom application metrics

### Service Dependencies
The observability stack follows this startup order:
1. Jaeger and Prometheus (backends)
2. OpenTelemetry Collector (aggregator)
3. Application services (Ollama, Open WebUI, etc.)
4. Grafana (visualization)

## Environment Variables

Key OpenTelemetry environment variables:
- `OTEL_EXPORTER_OTLP_ENDPOINT`: Collector endpoint for services
- `OTEL_SERVICE_NAME`: Service identification in traces
- `OTEL_RESOURCE_ATTRIBUTES`: Additional service metadata

## Monitoring and Alerting

### Grafana Dashboards
The Grafana instance includes provisioned datasources for:
- Prometheus (metrics)
- Jaeger (traces)

### Custom Dashboards
Add custom dashboard JSON files to `grafana/provisioning/dashboards/json/` to automatically provision them.

### Prometheus Targets
Current scrape targets include:
- OpenTelemetry Collector metrics
- Jaeger metrics
- Prometheus self-monitoring
- Traefik metrics (if configured)

## Troubleshooting

### Check OpenTelemetry Collector
```bash
docker compose logs otel-collector
```

### Verify Prometheus Targets
Visit Prometheus UI → Status → Targets to see scraping status.

### Check Jaeger Storage
```bash
docker compose logs jaeger
```

### Service Dependencies
If services fail to start, check the dependency order:
```bash
docker compose ps
docker compose logs <service-name>
```

## Security Considerations

- Sensitive data filtering is configured in the OpenTelemetry Collector
- Authentication is required for Ollama API access
- Grafana uses basic authentication
- Consider adding authentication to Prometheus and Jaeger for production use

## Scaling

For production deployments:
1. Use external storage for Jaeger (e.g., Elasticsearch, Cassandra)
2. Configure Prometheus for long-term storage (e.g., Thanos, Cortex)
3. Add resource limits to prevent resource exhaustion
4. Consider using dedicated OpenTelemetry Collector instances per service type

## Development

To add OpenTelemetry to new services:
1. Add the OTEL environment variables to the service
2. Update the OpenTelemetry Collector configuration if needed
3. Add Prometheus scrape targets for service metrics
4. Create Grafana dashboards for service-specific monitoring