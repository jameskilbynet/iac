# VMware Cloud Foundation Offline Bundle Server

Automated deployment of an Nginx-based web server for hosting VMware Cloud Foundation (VCF) offline bundles, with a browser upload page for dragging bundles across from your workstation.

## Overview

This playbook deploys an Nginx container that serves VMware Cloud Foundation offline bundles and patches, providing a local repository for VMware environment updates without requiring internet connectivity.

Bundles get onto the server by dragging them into the web page at `https://vcf.jameskilby.cloud/`. The page uploads over WebDAV `PUT` straight into `/vcf`, so there is no size cap, no staging copy, and no SSH needed.

## Features

- ✅ Deploys Nginx in Docker container
- ✅ Mounts host directory `/vcf` for bundle storage
- ✅ Drag-and-drop upload page with per-file progress, speed and ETA
- ✅ Browse subdirectories, copy bundle URLs for SDDC Manager, delete old bundles
- ✅ Uploads and deletes protected by Traefik basic auth; downloads stay anonymous
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
- An Nginx image built with `--with-http_dav_module` (the official `nginx:latest` is; the playbook checks and fails early if not)

### Traefik Read Timeout

**Re-run `../traefik/traefik_deploy.yml` before using the upload page.** Traefik v3 defaults `readTimeout` to 60 seconds, and that clock covers reading the request body — so every upload that takes longer than a minute is cut off mid-transfer with a dropped connection. The Traefik playbook now sets `readTimeout` to `3600s` on the `websecure` entrypoint (`traefik_read_timeout` to change it, `0` to remove the limit).

Symptom if you skip this: transfers die at roughly 60 seconds and the page reports "Connection dropped while sending …".

### DNS

If `vcf.jameskilby.cloud` is **proxied** through Cloudflare (orange cloud), uploads are capped at 100 MB on the free plan and every bundle will fail with HTTP 413. Set the record to DNS-only (grey cloud) — Traefik terminates TLS itself using the DNS-01 challenge, so proxying buys nothing here.

## Quick Start

### 1. Create Inventory File

```ini
[vcf_servers]
uk-bhr-p-doc-1.jameskilby.cloud ansible_user=your_username
```

### 2. Set Upload Credentials

Generate a bcrypt hash and keep only the part after the colon:

```bash
htpasswd -nB vcf
# vcf:$2y$05$EXAMPLEHASHREPLACEMEwithYourOwnHtpasswdOutputXXXXXXXX
```

Put it in a vars file (git-ignored) or Ansible Vault:

```yaml
# vars.yml
vcf_upload_user: vcf
vcf_upload_password_hash: "$2y$05$EXAMPLEHASHREPLACEMEwithYourOwnHtpasswdOutputXXXXXXXX"
```

Either name works, as an Ansible variable or as a controller environment variable:

| Ansible variable | Environment variable |
|------------------|----------------------|
| `vcf_upload_password_hash` | `VCF_UPLOAD_PASSWORD_HASH` |
| `vcf_upload_password` | `VCF_UPLOAD_PASSWORD` |
| `vcf_upload_user` | `VCF_UPLOAD_USER` |

### 3. Run the Playbook

```bash
ansible-playbook -i inventory.ini -e @vars.yml install_offline_bundle_server.yml
```

#### Running from Semaphore

A variable group has two separate buckets and they do not reach Ansible the same way:

- **Extra variables** → passed as `--extra-vars`, so use the `vcf_upload_password_hash` spelling.
- **Environment variables** (and secrets of that type) → exported into the process environment, where Ansible does **not** see them as variables. Use the `VCF_UPLOAD_PASSWORD_HASH` spelling instead.

The playbook reads both, so either bucket works — but the name has to match the bucket, and the variable group must be attached to the template. If the credential check fails, its message lists which of the four sources it actually found.

A bcrypt hash contains `$`. Paste it into Semaphore as a plain value; do not wrap it in a shell command or double quotes in a script, or `$2y` and `$05` get expanded away.

### 4. Upload VCF Bundles

Open `https://vcf.jameskilby.cloud/`, click **Sign in**, then drag bundles from Finder or Explorer onto the page. Transfers run one at a time with live progress; keep the tab open until they finish.

`scp` still works if you prefer it:

```bash
scp VMware-Cloud-Foundation-Bundle-*.zip user@server:/vcf/
rsync -avz --progress /path/to/bundles/ user@server:/vcf/
```

Files copied in over SSH show up in the page's listing immediately.

## Configuration Details

### Container Configuration

| Setting | Value |
|---------|-------|
| **Image** | `nginx:latest` |
| **Container Name** | `VCF_Offline_Bundle_Server` |
| **Bundle Mount** | `/vcf:/srv/vcf:rw` |
| **Config Mount** | `/etc/vcf-bundle-server/default.conf:/etc/nginx/conf.d/default.conf:ro` |
| **UI Mount** | `/etc/vcf-bundle-server/ui:/usr/share/nginx/ui:ro` |
| **Network** | `traefik` |
| **Restart Policy** | `always` |

The upload page is mounted read-only and outside the bundle root, so it never shows up in listings and cannot be overwritten through the upload endpoint.

### Endpoints

| Path | Methods | Auth | Purpose |
|------|---------|------|---------|
| `/` | GET | none | Drag-and-drop upload page |
| `/<filename>` | GET | none | Bundle download — this is the URL SDDC Manager consumes |
| `/api/files/<dir>/` | GET | none | JSON directory listing used by the page |
| `/api/upload/<path>` | PUT, DELETE | basic | Upload and delete |

### Playbook Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `vcf_hostname` | `vcf.jameskilby.cloud` | Traefik host rule |
| `vcf_bundle_path` | `/vcf` | Host directory holding the bundles |
| `vcf_nginx_image` | `nginx:latest` | Image to deploy |
| `vcf_upload_auth_enabled` | `true` | Gate PUT/DELETE behind basic auth |
| `vcf_upload_user` | `vcf` | Basic auth username |
| `vcf_upload_password_hash` | — | bcrypt hash from `htpasswd -nB` |
| `vcf_upload_password` | — | Plaintext alternative, hashed on the controller (needs passlib) |
| `vcf_certresolver` | `cloudflare` | Traefik certificate resolver |
| `vcf_worker_uid` / `vcf_worker_gid` | `101` | Nginx worker identity; owns `/vcf` so uploads can be written |

### Traefik Integration

The playbook configures Traefik labels for automatic routing. Two routers share one service: a low-priority router that serves everything anonymously, and a higher-priority router that matches only write methods and puts basic auth in front of them.

```yaml
# HTTPS router — browse and download, anonymous
traefik.http.routers.vcf.rule: "Host(`vcf.jameskilby.cloud`)"
traefik.http.routers.vcf.entrypoints: "websecure"
traefik.http.routers.vcf.tls: "true"
traefik.http.routers.vcf.tls.certresolver: "cloudflare"
traefik.http.routers.vcf.priority: "10"

# HTTPS router — uploads and deletes, authenticated
traefik.http.routers.vcf-write.rule: "Host(`vcf.jameskilby.cloud`) && (Method(`PUT`) || Method(`DELETE`))"
traefik.http.routers.vcf-write.priority: "100"
traefik.http.routers.vcf-write.middlewares: "vcf-auth"
traefik.http.middlewares.vcf-auth.basicauth.users: "vcf:$2y$05$..."

# HTTP router with redirect
traefik.http.routers.vcf-http.rule: "Host(`vcf.jameskilby.cloud`)"
traefik.http.routers.vcf-http.entrypoints: "web"
traefik.http.routers.vcf-http.middlewares: "redirect-to-https"
```

Keeping downloads anonymous matters: SDDC Manager pulls bundles by plain URL and has nowhere sensible to put credentials.

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

Override the variable, no playbook edit needed:

```bash
ansible-playbook -i inventory.ini -e vcf_hostname=bundles.yourdomain.com \
  -e @vars.yml install_offline_bundle_server.yml
```

### Additional Directories

Create subdirectories for organization:

```bash
ssh user@server
sudo mkdir -p /vcf/{bundles,patches,isos,drivers}
sudo chown 101:101 /vcf/*
```

The upload page navigates into subdirectories and drops files into whichever one you are viewing.

### Open Uploads

To drop basic auth entirely (only sane on an isolated network):

```bash
ansible-playbook -i inventory.ini -e vcf_upload_auth_enabled=false \
  install_offline_bundle_server.yml
```

### Custom Nginx Configuration

The site config is generated by the playbook into `/etc/vcf-bundle-server/default.conf` and mounted read-only. Edit the `vcf_nginx_config` block in the playbook and re-run; the container is restarted automatically when the file changes.

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
curl -s https://vcf.jameskilby.cloud/api/files/ | jq -r '.[] | select(.type=="file") | "\(.size)\t\(.name)"'

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

### Upload Rejected — 401

Basic auth turned you away. Sign out and back in on the page. If it keeps failing, the hash in your vars file does not match the password — regenerate with `htpasswd -nB vcf` and re-run the playbook. Check what Traefik loaded:

```bash
docker inspect VCF_Offline_Bundle_Server \
  --format '{{ index .Config.Labels "traefik.http.middlewares.vcf-auth.basicauth.users" }}'
```

### Upload Rejected — 413

Something in front of Nginx is capping the request body. Almost always Cloudflare proxying (100 MB on the free plan) — set the DNS record to DNS-only. Nginx itself is configured with `client_max_body_size 0`, and Traefik does not limit bodies unless a buffering middleware says so.

### Upload Rejected — 405

Nginx did not handle the `PUT`, which means the WebDAV module is missing or the config did not load:

```bash
docker exec VCF_Offline_Bundle_Server nginx -V 2>&1 | tr ' ' '\n' | grep dav
docker exec VCF_Offline_Bundle_Server nginx -t
```

### Uploads Fail Mid-Transfer

Check free space and the Nginx error log — a full disk shows up here first:

```bash
df -h /vcf
docker logs --tail 50 VCF_Offline_Bundle_Server
```

### Permission Issues

The Nginx worker runs as uid 101 and must be able to write into `/vcf`. Do **not** chown it back to root — uploads will start returning 500.

```bash
sudo chown -R 101:101 /vcf
sudo chmod 755 /vcf
sudo chmod 700 /vcf/.upload-tmp
```

### Bundles Not Visible

Ensure files are in the correct location:
```bash
ls -lh /vcf/*.zip
```

Subdirectories are browsable from the page and over HTTP (`https://vcf.jameskilby.cloud/patches/ESXi-8.0U2-patch.zip`), so symlinking them into the root is no longer needed. Files whose names start with a dot are hidden deliberately.

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

- **Write access**: `PUT` and `DELETE` require basic auth over HTTPS. Reads are deliberately anonymous — treat anything in `/vcf` as public to anyone who can resolve the hostname
- **Credentials**: keep the bcrypt hash in Ansible Vault or a git-ignored vars file; never commit the plaintext password
- **Access Control**: Traefik provides HTTPS encryption
- **Network Isolation**: Container uses traefik network
- **File Permissions**: `/vcf` is owned by uid 101 so the Nginx worker can write uploads; uploaded files land as 0664
- **Hidden paths**: anything beginning with a dot, including the upload temp directory, returns 404
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
