# AIStack Backup Guide

## Overview

The AIStack configuration now includes an automated backup service that handles backing up all application data and configurations. AI models are stored on NFS for centralized management and are backed up separately through your NAS backup strategy.

## Storage Architecture

### NFS Storage (192.168.60.x)
- **Ollama Models**: `:/mnt/pool1/docker/aistack/ollama`
- **Shared Models**: `:/mnt/pool1/docker/aistack/models`

### Local Docker Volumes
- Application data (OpenWebUI, Grafana, Prometheus, etc.)
- Monitoring data (Jaeger traces, metrics)
- Configuration data

## Backup Service

### Configuration
The backup service is configured with the following environment variables in `.env`:

```bash
BACKUP_RETENTION_DAYS=7      # Keep backups for 7 days
BACKUP_COMPRESS=true         # Compress backups to save space
```

### Manual Backup
To run a backup manually:

```bash
# Run backup using the backup profile
docker compose --profile backup up backup

# Or run it in detached mode
docker compose --profile backup up -d backup

# Check backup logs
docker compose logs backup
```

### Automated Backup
To set up automated backups, add a cron job:

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /path/to/aistack && docker compose --profile backup up backup >> /var/log/aistack-backup.log 2>&1

# Add weekly cleanup (optional, as backup service handles retention)
0 3 * * 0 find /path/to/aistack/backups -name 'aistack-backup-*' -type d -mtime +7 -exec rm -rf {} +
```

### Backup Contents

The backup service creates compressed archives of:
- **ollama-config**: Ollama configuration (models stored separately on NFS)
- **openwebui**: OpenWebUI data and configurations
- **grafana**: Grafana dashboards and settings
- **prometheus**: Prometheus configuration and short-term metrics
- **jaeger**: Jaeger trace data
- **hoarder**: Hoarder bookmarks and data
- **meilisearch**: Search index data
- **searxng**: Search engine configurations

### Backup Location
Backups are stored in `./backups/` with timestamped directories:
```
backups/
├── aistack-backup-20240122_140530/
│   ├── backup-info.txt
│   ├── ollama-config.tar.gz
│   ├── openwebui.tar.gz
│   ├── grafana.tar.gz
│   └── ...
└── aistack-backup-20240123_140530/
    └── ...
```

## Restoration Process

### 1. Stop Services
```bash
docker compose down
```

### 2. Restore Data
```bash
# Navigate to backup directory
cd backups/aistack-backup-YYYYMMDD_HHMMSS

# Extract service data
tar -xzf grafana.tar.gz -C /path/to/grafana/data/
tar -xzf prometheus.tar.gz -C /path/to/prometheus/data/
# ... repeat for other services
```

### 3. Restart Services
```bash
docker compose up -d
```

## Model Management

### NFS Benefits
- **Centralized Storage**: Models accessible from multiple containers/hosts
- **Backup Integration**: Models backed up as part of NAS backup strategy
- **Scalability**: Easy to add more AI services sharing the same models
- **Performance**: NFS caching improves model loading times

### Model Backup Strategy
Since models are stored on NFS (192.168.60.x), ensure your NAS has:
1. **Regular snapshots** of `/mnt/pool1/docker/aistack/`
2. **Off-site backup** for disaster recovery
3. **Version control** for model updates

## Monitoring Backups

### Check Backup Status
```bash
# List recent backups
ls -la backups/

# Check backup info
cat backups/aistack-backup-latest/backup-info.txt

# Verify backup integrity
docker run --rm -v $(pwd)/backups:/backups alpine:latest \
  find /backups -name "*.tar.gz" -exec tar -tzf {} \; > /dev/null
```

### Backup Size Monitoring
```bash
# Check total backup size
du -sh backups/

# Check individual backup sizes
du -sh backups/*/
```

## Best Practices

1. **Test Restores**: Regularly test backup restoration in a test environment
2. **Monitor Disk Space**: Ensure sufficient space for backup retention
3. **Verify NFS Health**: Monitor NFS mount status and performance
4. **Document Changes**: Keep track of configuration changes for restore context
5. **Security**: Ensure backup directory has appropriate permissions (600/700)

## Troubleshooting

### Backup Fails
```bash
# Check backup container logs
docker compose logs backup

# Verify volume mounts
docker compose config

# Test NFS connectivity
docker run --rm -v ollama_storage:/test alpine:latest ls -la /test
```

### NFS Issues
```bash
# Check NFS mount status
mount | grep nfs

# Test NFS connectivity
ping 192.168.60.x

# Verify NFS exports on server
showmount -e 192.168.60.x
```

### Storage Full
```bash
# Check disk usage
df -h

# Clean old backups manually
find backups/ -name 'aistack-backup-*' -mtime +7 -exec rm -rf {} +

# Reduce retention period in .env
BACKUP_RETENTION_DAYS=3
```

## Recovery Scenarios

### Complete Disaster Recovery
1. Restore from off-site NAS backup
2. Deploy fresh AIStack instance
3. Restore application data from backups
4. Verify all services are functioning

### Partial Recovery
1. Identify failed service
2. Stop specific service: `docker compose stop grafana`
3. Restore service data from backup
4. Restart service: `docker compose up -d grafana`

This backup strategy ensures your AIStack deployment is resilient while leveraging your existing NFS infrastructure for optimal performance and centralized management.