# AIStack Docker Compose - Improvements and Recommendations

## Current State Analysis

The aistack configuration is a comprehensive AI/ML observability and management platform including:
- OpenTelemetry Collector for telemetry data
- Jaeger for distributed tracing
- Prometheus for metrics collection
- Grafana for visualization
- Ollama for LLM inference
- Open WebUI for chat interface
- SearxNG for web search
- Hoarder for bookmark management
- Chrome headless for web scraping

## Recommended Improvements

### 1. Security Enhancements

#### Environment Variables
- **Issue**: Hardcoded credentials in .env file
- **Fix**: Use Docker secrets or external secret management
```yaml
# Add to docker-compose.yml
secrets:
  grafana_password:
    file: ./secrets/grafana_password.txt
  meili_master_key:
    file: ./secrets/meili_master_key.txt
```

#### Container Security
```yaml
# Add to all services
security_opt:
  - no-new-privileges:true
read_only: true  # where possible
tmpfs:
  - /tmp:noexec,nosuid,size=100m  # for read-only containers
```

### 2. Resource Management

#### Memory and CPU Limits
```yaml
# Add to resource-intensive services like Ollama, Grafana, Prometheus
deploy:
  resources:
    limits:
      memory: 4G
      cpus: '2.0'
    reservations:
      memory: 1G
      cpus: '0.5'
```

#### Health Checks
```yaml
# Add to all services
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:port/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

### 3. Logging Improvements

#### Structured Logging
```yaml
# Add to all services
logging:
  driver: "json-file"
  options:
    max-file: "3"
    max-size: "10m"
    tag: "{{.ImageName}}|{{.Name}}"
```

### 4. Volume and Data Management

#### Backup Strategy
```yaml
# Add backup volumes
volumes:
  ollama_storage:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/aistack/ollama  # Easier to backup
```

#### External Storage Integration
Based on your homelab setup, consider adding NFS mounts for shared model storage:
```yaml
volumes:
  shared_models:
    driver_opts:
      type: "nfs"
      o: "addr=192.168.60.x,rw,nolock,soft"
      device: ":/mnt/pool1/dockermounts/aistack/models"
```

### 5. Network Security

#### Internal Networks
```yaml
networks:
  traefik:
    external: true
  aistack-internal:
    driver: bridge
    internal: true  # No external access
    ipam:
      config:
        - subnet: 172.30.0.0/16
```

### 6. Configuration Management

#### Environment File Improvements
- Split configurations by service
- Use template files with placeholders
- Add validation for required variables

### 7. Service Dependencies

#### Improve Dependency Management
```yaml
# Add proper dependency chains with conditions
depends_on:
  prometheus:
    condition: service_healthy
  jaeger:
    condition: service_started
```

### 8. Monitoring Enhancements

#### Add Node Exporter
```yaml
node-exporter:
  image: prom/node-exporter:latest
  container_name: node-exporter
  restart: unless-stopped
  volumes:
    - /proc:/host/proc:ro
    - /sys:/host/sys:ro
    - /:/rootfs:ro
  command:
    - '--path.procfs=/host/proc'
    - '--path.rootfs=/rootfs'
    - '--path.sysfs=/host/sys'
```

#### cAdvisor for Container Metrics
```yaml
cadvisor:
  image: gcr.io/cadvisor/cadvisor:latest
  container_name: cadvisor
  restart: unless-stopped
  volumes:
    - /:/rootfs:ro
    - /var/run:/var/run:rw
    - /sys:/sys:ro
    - /var/lib/docker/:/var/lib/docker:ro
```

### 9. Performance Optimizations

#### Ollama Optimizations
```yaml
ollama:
  environment:
    # GPU memory management
    - CUDA_VISIBLE_DEVICES=0
    - OLLAMA_NUM_PARALLEL=2
    - OLLAMA_MAX_LOADED_MODELS=3
    # Performance tuning
    - OLLAMA_FLASH_ATTENTION=1
    - OLLAMA_KV_CACHE_TYPE=f16
```

### 10. Backup and Recovery

#### Add Backup Service
```yaml
backup:
  image: alpine:latest
  container_name: aistack-backup
  volumes:
    - ollama_storage:/backup/ollama:ro
    - grafana_data:/backup/grafana:ro
    - prometheus_data:/backup/prometheus:ro
  command: |
    sh -c "
    tar -czf /backup/aistack-backup-$(date +%Y%m%d).tar.gz \
      /backup/ollama /backup/grafana /backup/prometheus
    "
  profiles: ["backup"]  # Only run when specifically requested
```

### 11. Development vs Production

#### Use Profiles for Environment-Specific Services
```yaml
services:
  debug-service:
    profiles: ["debug", "development"]
  
  production-optimizer:
    profiles: ["production"]
```

## Implementation Priority

1. **High Priority**: Security improvements, resource limits, health checks
2. **Medium Priority**: Monitoring enhancements, backup strategy
3. **Low Priority**: Performance optimizations, development tools

## Next Steps

1. Implement security improvements first
2. Add external storage mounts for shared models
3. Set up proper backup procedures
4. Consider adding a reverse proxy authentication layer
5. Implement log aggregation (ELK stack or Loki/Grafana)

These improvements will enhance security, reliability, and maintainability of your AI stack while following Docker best practices.