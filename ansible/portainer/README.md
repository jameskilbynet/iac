# Portainer Agent Deployment with Ansible

Automated deployment of Portainer Agent on Docker hosts for centralized container management and monitoring.

## Overview

This directory contains an Ansible playbook for deploying Portainer Agent and a bash script for generating comprehensive inventory reports from your Portainer instance.

## Files

- `install_portainer_agent.yml` - Ansible playbook to deploy Portainer Agent containers
- `portainer-inventory.sh` - Bash script to generate Markdown inventory reports from Portainer API

## Features

### Portainer Agent Deployment
- ✅ Deploys Portainer Agent as a Docker container
- ✅ Exposes port 9001 for management interface
- ✅ Mounts Docker socket for full container access
- ✅ Mounts Docker volumes for management
- ✅ Provides host filesystem access
- ✅ Uses pinned version for stability
- ✅ Automatic restart policy

### Inventory Script
- ✅ Authenticates with Portainer API
- ✅ Generates comprehensive Markdown reports
- ✅ Lists all environments/endpoints
- ✅ Shows stacks and their containers
- ✅ Identifies orphan containers
- ✅ Includes container details (ports, volumes, networks)
- ✅ Separates running and stopped containers

## Prerequisites

### For Portainer Agent Playbook

#### Control Machine (Local)
- Ansible 2.9+
- `community.docker` collection installed
- SSH access to target host(s)

#### Target Host
- Ubuntu/Debian operating system
- Docker and Docker Compose installed (see `../docker/install_docker.yml`)
- SSH access with sudo privileges
- Port 9001 available

### For Inventory Script

- Bash shell
- `curl` command-line tool
- `jq` JSON processor
- Access to Portainer instance
- Valid Portainer credentials

## Quick Start

### Deploy Portainer Agent

#### 1. Install Required Ansible Collection

```bash
ansible-galaxy collection install community.docker
```

#### 2. Create Inventory File

Create `inventory.ini`:

```ini
[portainer_agents]
server1.example.com ansible_user=your_username
server2.example.com ansible_user=your_username
```

#### 3. Run the Playbook

```bash
ansible-playbook -i inventory.ini install_portainer_agent.yml
```

#### 4. Verify Installation

```bash
# Check if container is running
ansible portainer_agents -i inventory.ini -m shell -a "docker ps | grep portainer_agent"

# Check connectivity
curl http://server1.example.com:9001
```

### Generate Inventory Report

#### 1. Create Environment File

Create a `.env` file in the portainer directory:

```bash
PORTAINER_URL="https://portainer.example.com/api"
USERNAME="admin"
PASSWORD="your_portainer_password"
```

**Security Note**: Never commit `.env` to version control!

#### 2. Run the Script

```bash
./portainer-inventory.sh
```

#### 3. View the Report

The script generates `portainer-inventory.md` with a complete inventory of all your environments, stacks, and containers.

## Playbook Details

### Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `portainer_agent_image` | `portainer/agent:2.19.4` | Portainer Agent Docker image |
| `container_name` | `portainer_agent` | Name for the agent container |
| `host_port` | `9001` | Host port to expose |

### Volume Mounts

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `/var/run/docker.sock` | `/var/run/docker.sock` | Docker socket access |
| `/var/lib/docker/volumes` | `/var/lib/docker/volumes` | Docker volumes management |
| `/` | `/host` | Host filesystem access |

### Container Configuration

- **Restart Policy**: `always`
- **Network Mode**: Bridge (default)
- **Privileged Mode**: No (uses socket mounting instead)

## Inventory Script Details

### Usage

```bash
# Generate inventory
./portainer-inventory.sh

# Show version
./portainer-inventory.sh --version
# or
./portainer-inventory.sh -v
```

### Output Format

The script generates a Markdown file with the following structure:

```markdown
# Portainer Inventory Report
Generated on DD/MM/YYYY
Script version: vX.Y.Z

## Environment: environment-name (ID: X)

### Stack: stack-name
- **ID:** X
- **Type:** compose/swarm
- **Status:** active

#### Running Containers
| Name | Image | Status | Ports | Environment | ID | Volumes | Networks |
|------|-------|--------|-------|-------------|----|---------|----------|
| ... | ... | ... | ... | ... | ... | ... | ... |

#### Stopped Containers
...

## Orphan Containers (Not in Any Stack)
...
```

### Custom Header

You can add a custom header to the report by creating `templates/header.md`:

```markdown
# My Organization
## Container Infrastructure Report
This report is generated automatically from our Portainer instance.
```

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PORTAINER_URL` | Yes | Portainer API URL (e.g., `https://portainer.example.com/api`) |
| `USERNAME` | Yes | Portainer username |
| `PASSWORD` | Yes | Portainer password |

### Script Features

- **Authentication**: Uses JWT token-based authentication
- **All Endpoints**: Queries all configured Portainer endpoints
- **Stack Information**: Groups containers by Docker Compose stack
- **Container Details**: Includes ports, volumes, networks, and status
- **Orphan Detection**: Identifies containers not managed by stacks
- **Error Handling**: Validates authentication and provides error messages

## Integration with Portainer Server

### Adding Agent to Portainer Server

After deploying the agent:

1. Log into your Portainer server web UI
2. Navigate to **Environments** → **Add environment**
3. Select **Docker** → **Agent**
4. Enter the agent details:
   - **Name**: Descriptive name for the environment
   - **Environment URL**: `server1.example.com:9001`
5. Click **Connect**

### Security Considerations

- **TLS**: Consider using TLS for production (requires certificates)
- **Firewall**: Restrict port 9001 to Portainer server IP only
- **Docker Socket**: Agent has full Docker access - secure the host
- **Network Segmentation**: Use separate networks for management traffic
- **API Credentials**: Store Portainer credentials securely (Ansible Vault, etc.)

## Advanced Usage

### Custom Agent Port

```bash
ansible-playbook -i inventory.ini install_portainer_agent.yml \
  -e "host_port=9002"
```

### Different Agent Version

```bash
ansible-playbook -i inventory.ini install_portainer_agent.yml \
  -e "portainer_agent_image=portainer/agent:2.20.0"
```

### Update Existing Agent

The playbook is idempotent and will update the container if already exists:

```bash
ansible-playbook -i inventory.ini install_portainer_agent.yml
```

### Automated Inventory Reports

Schedule the inventory script with cron:

```bash
# Run daily at 6 AM
0 6 * * * cd /path/to/portainer && ./portainer-inventory.sh
```

## Troubleshooting

### Agent Container Won't Start

```
Error starting userland proxy: listen tcp4 0.0.0.0:9001: bind: address already in use
```

**Solution**: Port 9001 is in use. Either:
- Stop the conflicting service
- Use a different port: `-e "host_port=9002"`

### Cannot Connect to Docker Socket

```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**Solution**: Ensure Docker is installed and running:

```bash
sudo systemctl status docker
sudo systemctl start docker
```

### Portainer Cannot Connect to Agent

**Symptoms**: Agent shows as "down" in Portainer UI

**Solutions**:
1. Verify agent is running: `docker ps | grep portainer_agent`
2. Check firewall allows port 9001
3. Test connectivity: `curl http://agent-host:9001`
4. Review agent logs: `docker logs portainer_agent`

### Inventory Script Authentication Failed

```
Authentication failed:
```

**Solution**: Verify credentials in `.env`:
- Check PORTAINER_URL is correct (include `/api`)
- Verify USERNAME and PASSWORD are correct
- Ensure Portainer server is accessible

### Inventory Script Missing Dependencies

```
jq: command not found
```

**Solution**: Install jq:

```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# Red Hat/CentOS
sudo yum install jq
```

## Maintenance

### Update Portainer Agent

1. Update the version in playbook or use extra vars
2. Re-run the playbook:

```bash
ansible-playbook -i inventory.ini install_portainer_agent.yml \
  -e "portainer_agent_image=portainer/agent:latest"
```

### Remove Portainer Agent

```bash
ansible portainer_agents -i inventory.ini -b -m shell \
  -a "docker stop portainer_agent && docker rm portainer_agent"
```

### Backup Agent Configuration

The agent itself is stateless, but you may want to document your environment configuration:

```bash
docker inspect portainer_agent > portainer_agent_config.json
```

## Integration with Infrastructure

This playbook integrates with:
- **Docker Installation** (`../docker/install_docker.yml`) - Required prerequisite
- **Traefik** - Can be managed via Portainer after agent deployment
- **Container Stacks** - All containers can be managed through Portainer

## Additional Resources

- [Portainer Documentation](https://docs.portainer.io/)
- [Portainer Agent Documentation](https://docs.portainer.io/admin/environments/add/docker/agent)
- [Portainer API Documentation](https://docs.portainer.io/api/)
- [Docker Documentation](https://docs.docker.com/)
- [Main Project README](../README.md)

## License

### Playbook
Part of the infrastructure automation project. See main project documentation for licensing.

### Inventory Script
MIT License - Copyright (c) 2025 Christian Mohn

The script is provided "as is" without warranty. See the script header for full license text.

## Contributing

When modifying these tools:

1. Test the playbook on clean systems
2. Verify agent connectivity with Portainer server
3. Test inventory script with multiple environments
4. Update this README with changes
5. Follow Ansible and bash best practices

## Support

For issues related to:
- **Portainer Agent**: Check [Portainer documentation](https://docs.portainer.io/)
- **Ansible Playbooks**: See the [main project README](../README.md)
- **Inventory Script**: Review script comments and API documentation
- **Docker**: Verify Docker installation and status
