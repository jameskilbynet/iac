# Hoarder Stack

A dedicated Docker Compose stack for Hoarder - Personal Knowledge Management and Bookmark Manager.

## Services

- **Hoarder** - Main application for bookmarking and knowledge management
- **Chrome** - Headless Chrome for web scraping and screenshot generation  
- **Meilisearch** - Full-text search engine for indexed content
- **Backup** - Automated backup service (optional, manual execution)

## Storage

**All data stored locally for optimal compatibility and performance:**
- **Hoarder Database**: Local Docker volume (SQLite requires local filesystem)
- **Meilisearch Index**: Local Docker volume (better performance for database operations)
- **Assets & Files**: Local Docker volume (screenshots, downloads, uploads)

## Quick Start

### Prerequisites
- Traefik reverse proxy running
- Docker network `traefik` exists

### Deployment

```bash
# Start the stack
docker compose up -d

# Check logs
docker compose logs -f

# Access Hoarder
open https://hoarder.example.com
```

### Management Commands

```bash
# Stop services
docker compose down

# Update services
docker compose pull
docker compose up -d

# View status
docker compose ps

# Run backup
docker compose --profile backup run --rm backup
```

## Configuration

Environment variables are configured in `.env`:

- **NEXTAUTH_URL**: External URL for authentication
- **MEILI_MASTER_KEY**: Meilisearch authentication key
- **SMB credentials**: For persistent storage access
- **Backup settings**: Retention and compression options

## Backup

Manual backup execution:
```bash
# Create backup
docker compose --profile backup run --rm backup

# Backups stored in ./backups/ directory
ls -la backups/
```

## Troubleshooting

### SMB Mount Issues
```bash
# Check volume configuration
docker volume inspect hoarder_hoarder_data

# Test SMB connectivity
docker compose exec hoarder ping 192.168.60.x

# Check mount inside container
docker compose exec hoarder df -h | grep /data
```

### Service Issues
```bash
# Check all service logs
docker compose logs

# Check specific service
docker compose logs hoarder
docker compose logs meilisearch
```

## Network Access

- **Public**: https://hoarder.example.com (via Traefik)
- **Internal**: http://hoarder:3000 (container network)