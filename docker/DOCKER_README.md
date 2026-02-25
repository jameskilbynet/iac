# Docker Homelab Infrastructure

A comprehensive self-hosted infrastructure running 50+ services using Docker Compose with Traefik reverse proxy and automated SSL certificates.

## 🏗 Architecture Overview

### Core Infrastructure
- **[Traefik](traefik/README.md)** - Reverse proxy with automatic SSL certificates
- **[Authentik](authentik/README.md)** - Identity provider and single sign-on
- **[Homepage](homepage/README.md)** - Dashboard for accessing all services

### 🎬 Media Stack
- **[Plex](plex/README.md)** - Media server with GPU transcoding
- **[Sonarr](sonarr/README.md)** - TV show automation
- **[Radarr](radarr/README.md)** - Movie automation
- **[Tautulli](tautulli/README.md)** - Plex statistics and monitoring
- **[MeTube](metube/README.md)** - YouTube downloader

### 🤖 AI & Development
- **[n8n](n8n/README.md)** - Workflow automation
- **[CodeProject AI](codeprojectai/README.md)** - AI inference server
- **[Fooocus](fooocus/README.md)** - AI image generation
- **[Stable Diffusion](stablediffusion/README.md)** - Advanced AI image generation

### 📸 Photo Management
- **[Immich](immich/README.md)** - Self-hosted photo backup with AI features

### 📊 Monitoring & Analytics
- **[Uptime Kuma](uptimekuma/README.md)** - Service uptime monitoring
- **[AutoKuma](autokuma/README.md)** - Automatic Uptime Kuma monitor management
- **[Beszel](beszel/README.md)** - System monitoring
- **[Ghostfolio](ghostfolio/README.md)** - Portfolio tracking

### 🛠 Utilities
- **[CyberChef](cyberchef/README.md)** - Data analysis and transformation
- **[Excalidraw](excalidraw/README.md)** - Collaborative whiteboard
- **[UniFi Controller](unifi/README.md)** - Network management

### 📄 Document Management
- **[Paperless-ngx](paperless/README.md)** - Document management system
- **[Nextcloud](nextcloud/README.md)** - File sync and collaboration

### 🔧 Infrastructure Management
- **[Semaphore](semaphore/README.md)** - Ansible UI

## 🚀 Quick Start

### Prerequisites
1. Docker and Docker Compose installed
2. Domain name with Cloudflare DNS
3. Cloudflare API token for SSL certificates

### Initial Setup
```bash
# Clone the repository
git clone https://github.com/your-username/Docker.git
cd Docker

# Create the Traefik network
docker network create traefik

# Start Traefik first (required by all other services)
cd traefik && docker compose up -d

# Start other services as needed
cd ../plex && docker compose up -d
cd ../sonarr && docker compose up -d
# etc...
```

## 🔧 Configuration

### Environment Variables
Most services use `.env` files for configuration. Key patterns:

```bash
# Standard user/group IDs
PUID=1000
PGID=1000

# Timezone
TZ=Etc/UTC

# Database credentials
DB_USER=your_username
DB_PASS=your_password_here
DB_NAME=database_name
```

### Traefik Labels
All services use consistent Traefik labels:
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.service.rule=Host(`service.example.com`)"
  - "traefik.http.routers.service.entrypoints=websecure"
  - "traefik.http.routers.service.tls=true"
  - "traefik.http.routers.service.tls.certresolver=cloudflare"
  - "traefik.http.services.service.loadbalancer.server.port=PORT"
```

### Storage Patterns
- **Local volumes**: Configuration and small data
- **NFS mounts**: Media files from `192.168.60.x`
- **CIFS mounts**: Network storage with credentials

## 📋 Service Categories

### Infrastructure (Start First)
1. **Traefik** - Must be started before any other service
2. **Authentik** - Identity provider for SSO
3. **Homepage** - Central dashboard

### Media Services
- All media services connect to NFS storage at `192.168.60.x`
- Plex provides media serving with GPU acceleration
- Arr stack (Sonarr/Radarr) automates media acquisition

### AI/GPU Services
- Services with GPU requirements need NVIDIA drivers
- GPU resources are shared across AI services
- CUDA 11.7+ required for optimal performance

### Monitoring
- Uptime Kuma monitors all services
- Beszel provides system metrics
- Tautulli tracks media consumption

## 🛠 Management Commands

### Bulk Operations
```bash
# Start multiple services
for dir in plex sonarr radarr; do
  docker compose -f $dir/docker-compose.yml up -d
done

# Update all services
find . -name "docker-compose.yml" -execdir docker compose pull \;
find . -name "docker-compose.yml" -execdir docker compose up -d \;

# Stop all services (excluding Traefik)
find . -name "docker-compose.yml" -not -path "./traefik/*" -execdir docker compose down \;
```

### Service Management
```bash
# Start a service
docker compose -f service/docker-compose.yml up -d

# View logs
docker compose -f service/docker-compose.yml logs -f

# Update service
docker compose -f service/docker-compose.yml pull
docker compose -f service/docker-compose.yml up -d
```

## 🔐 Security Features

### Network Security
- All services isolated in Docker networks
- Traefik handles SSL termination
- Internal communication encrypted

### Authentication
- Authentik provides SSO for compatible services
- Individual service authentication where needed
- API key management for automation

### SSL Certificates
- Automatic Let's Encrypt certificates via Cloudflare DNS
- Wildcard certificate for `*.example.com`
- Automatic renewal and deployment

## 💾 Backup Strategy

### Critical Data
- **Configuration files**: All `.env` files and compose files
- **Docker volumes**: Application data
- **Media files**: Separate backup of NFS storage
- **Databases**: Regular database dumps

### Backup Script Example
```bash
#!/bin/bash
BACKUP_DIR="/backups/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup configurations
tar -czf "$BACKUP_DIR/configs.tar.gz" --exclude="*/README.md" */

# Backup Docker volumes
docker run --rm -v /var/lib/docker/volumes:/volumes -v "$BACKUP_DIR":/backup alpine \
  tar -czf /backup/volumes.tar.gz /volumes

echo "Backup completed: $BACKUP_DIR"
```

## 📊 Resource Requirements

### Minimum System Requirements
- **CPU**: 8 cores recommended
- **RAM**: 32GB for full stack
- **Storage**: 1TB+ SSD for containers
- **Network**: Gigabit connection
- **GPU**: NVIDIA GPU for AI services (optional)

### Resource Allocation
- **Infrastructure**: 4GB RAM
- **Media Stack**: 8GB RAM
- **AI Services**: 16GB RAM + GPU
- **Monitoring**: 2GB RAM
- **Other Services**: 8GB RAM

## 🔍 Troubleshooting

### Common Issues
1. **Service not accessible**: Check Traefik labels and network configuration
2. **SSL certificate issues**: Verify Cloudflare API token
3. **Permission errors**: Check PUID/PGID settings
4. **Storage mount failures**: Verify NFS/CIFS server connectivity

### Debug Commands
```bash
# Check all running containers
docker ps -a

# Inspect Traefik network
docker network inspect traefik

# View service logs
docker compose logs -f service-name

# Check resource usage
docker stats
```

## 📚 Documentation

Each service has its own detailed README with:
- Service-specific configuration
- Troubleshooting guides
- Feature explanations
- Best practices

Navigate to individual service directories for detailed documentation.

## 🔄 Updates & Maintenance

### Regular Maintenance
- **Weekly**: Update containers with critical security patches
- **Monthly**: Full system update and backup verification
- **Quarterly**: Review resource usage and optimize

### Update Process
1. Check service documentation for breaking changes
2. Backup critical data
3. Update images: `docker compose pull`
4. Restart services: `docker compose up -d`
5. Verify functionality

## 📈 Monitoring & Observability

### Service Health
- Built-in health checks for critical services
- Uptime monitoring via Uptime Kuma
- Log aggregation recommendations

### Performance Monitoring
- System metrics via Beszel
- Resource usage tracking
- Storage capacity monitoring

## 🤝 Contributing

### Adding New Services
1. Copy `template/` directory
2. Update service name and configuration
3. Add Traefik labels with unique hostname
4. Create detailed README following established patterns
5. Test thoroughly before production deployment

### Service Standards
- Use official or well-maintained images
- Include health checks
- Follow security best practices
- Document configuration thoroughly

## 📄 License

This configuration is provided as-is for educational and personal use. Individual services retain their respective licenses.

---

**⚠️ Important**: This is a personal homelab configuration. Adapt security settings, credentials, and network configuration for your environment before use.
