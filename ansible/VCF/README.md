# VMware Cloud Foundation Offline Bundle Server

Automated deployment of an Nginx-based web server for hosting VMware Cloud Foundation (VCF) offline bundles.

## Overview

This playbook deploys an Nginx container that serves VMware Cloud Foundation offline bundles and patches, providing a local repository for VMware environment updates without requiring internet connectivity.

## Features

- ✅ Deploys Nginx in Docker container
- ✅ Mounts host directory `/vcf` for bundle storage
- ✅ Integrates with Traefik reverse proxy
- ✅ Automatic HTTPS via Traefik + Cloudflare
- ✅ HTTP to HTTPS redirect
- ✅ Always-restart policy for high availability
- ✅ Connected to traefik Docker network

## Prerequisites

### Target Host
- Docker installed (see `../docker/install_docker.yml`)
- Traefik deployed (see `../traefik/traefik_deploy.yml`)
- SSH access with sudo privileges
- Port 80 accessible (internally, Traefik handles external access)

## Quick Start

### 1. Create Inventory File

```ini
[vcf_servers]
uk-bhr-p-doc-1.jameskilby.cloud ansible_user=your_username
```

### 2. Run the Playbook

```bash
ansible-playbook -i inventory.ini install_offline_bundle_server.yml
```

### 3. Upload VCF Bundles

```bash
# Copy bundles to the server
scp VMware-Cloud-Foundation-Bundle-*.zip user@server:/vcf/

# Or use rsync
rsync -avz --progress /path/to/bundles/ user@server:/vcf/
```

### 4. Access the Server

Visit `https://vcf.jameskilby.cloud` to browse available bundles.

## Configuration Details

### Container Configuration

| Setting | Value |
|---------|-------|
| **Image** | `nginx:latest` |
| **Container Name** | `VCF_Offline_Bundle_Server` |
| **Volume Mount** | `/vcf:/usr/share/nginx/html:rw` |
| **Network** | `traefik` |
| **Restart Policy** | `always` |

### Traefik Integration

The playbook configures Traefik labels for automatic routing:

```yaml
# HTTPS router
traefik.http.routers.vcf.rule: "Host(`vcf.jameskilby.cloud`)"
traefik.http.routers.vcf.entrypoints: "websecure"
traefik.http.routers.vcf.tls: "true"
traefik.http.routers.vcf.tls.certresolver: "cloudflare"

# HTTP router with redirect
traefik.http.routers.vcf-http.rule: "Host(`vcf.jameskilby.cloud`)"
traefik.http.routers.vcf-http.entrypoints: "web"
traefik.http.routers.vcf-http.middlewares: "redirect-to-https"
```

### Directory Structure

```
/vcf/
├── VMware-Cloud-Foundation-Bundle-4.5.0.0-12345678.zip
├── VMware-Cloud-Foundation-Bundle-4.5.1.0-87654321.zip
├── patches/
│   ├── ESXi-8.0U2-patch.zip
│   └── vCenter-8.0U2-patch.zip
└── README.txt
```

## Advanced Usage

### Custom Domain

Edit the playbook and change the domain in Traefik labels:

```yaml
traefik.http.routers.vcf.rule: "Host(`bundles.yourdomain.com`)"
traefik.http.routers.vcf-http.rule: "Host(`bundles.yourdomain.com`)"
```

### Additional Directories

Create subdirectories for organization:

```bash
ssh user@server
sudo mkdir -p /vcf/{bundles,patches,isos,drivers}
```

### Custom Nginx Configuration

Mount a custom nginx.conf:

```yaml
volumes:
  - "/vcf:/usr/share/nginx/html:rw"
  - "/path/to/nginx.conf:/etc/nginx/nginx.conf:ro"
```

## VMware VCF Integration

### Configure VCF to Use Offline Bundle Server

1. Log into SDDC Manager
2. Navigate to **Lifecycle Management** → **Bundle Management**
3. Select **Offline Bundle Transfer**
4. Enter: `https://vcf.jameskilby.cloud/VMware-Cloud-Foundation-Bundle-X.X.X.X-XXXXXXXX.zip`
5. Click **Transfer**

### Verify Bundle Availability

```bash
# List available bundles
curl -s https://vcf.jameskilby.cloud/ | grep -oP 'href="\K[^"]+\.zip'

# Check bundle size
curl -sI https://vcf.jameskilby.cloud/VMware-Cloud-Foundation-Bundle-4.5.0.0-12345678.zip | grep Content-Length
```

## Troubleshooting

### Container Not Starting

```bash
# Check container status
docker ps -a | grep VCF_Offline_Bundle_Server

# View logs
docker logs VCF_Offline_Bundle_Server

# Check if /vcf directory exists
ls -la /vcf
```

### Cannot Access via Traefik

**Check Traefik routing**:
```bash
docker logs traefik | grep vcf

# Verify container is on traefik network
docker inspect VCF_Offline_Bundle_Server | grep -A 10 Networks
```

**Verify DNS**:
```bash
dig vcf.jameskilby.cloud
```

### Permission Issues

```bash
# Fix /vcf directory permissions
sudo chown -R root:root /vcf
sudo chmod -R 755 /vcf
```

### Bundles Not Visible

Ensure files are in the correct location:
```bash
ls -lh /vcf/*.zip
```

If bundles are in subdirectories, adjust the Nginx root or use symlinks:
```bash
ln -s /vcf/bundles/*.zip /vcf/
```

## Maintenance

### Update Nginx Image

```bash
ansible-playbook -i inventory.ini install_offline_bundle_server.yml
# This will pull latest nginx image and recreate container
```

### Backup Bundles

```bash
# Create backup
tar -czf vcf-bundles-backup-$(date +%Y%m%d).tar.gz /vcf/

# Or sync to remote location
rsync -avz /vcf/ backup-server:/backups/vcf/
```

### Monitor Disk Space

```bash
# Check /vcf disk usage
du -sh /vcf

# Check available space
df -h /vcf
```

### Clean Old Bundles

```bash
# Remove bundles older than 6 months
find /vcf -name "*.zip" -type f -mtime +180 -delete
```

## Security Considerations

- **Access Control**: Traefik provides HTTPS encryption
- **Network Isolation**: Container uses traefik network
- **File Permissions**: /vcf should be readable only
- **Bundle Integrity**: Verify checksums after upload
- **Firewall**: Ensure only Traefik can access container port 80

## Integration with Infrastructure

This server integrates with:
- **Traefik**: For reverse proxy and SSL termination
- **Cloudflare**: For DNS and SSL certificates  
- **Docker**: Container runtime
- **VMware VCF**: Offline bundle consumption

## Additional Resources

- [VMware Cloud Foundation Documentation](https://docs.vmware.com/en/VMware-Cloud-Foundation/)
- [VCF Lifecycle Management](https://docs.vmware.com/en/VMware-Cloud-Foundation/services/vcf-lcm/GUID-8C93E0EB-0EDF-401A-A24B-8B7AF7DBDC5D.html)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Main Project README](../README.md)

## Support

For issues related to:
- **Nginx Container**: Check Docker and Nginx documentation
- **Traefik Routing**: See `../traefik/README.md`
- **VCF Bundles**: Check VMware Cloud Foundation documentation
- **Ansible Playbooks**: See the [main project README](../README.md)
