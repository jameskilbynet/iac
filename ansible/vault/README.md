# HashiCorp Vault Installation with Ansible

Automated installation and configuration of HashiCorp Vault for secrets management on Ubuntu systems.

## Overview

This playbook installs HashiCorp Vault from the official repository and configures it with file-based storage backend, suitable for development and small-scale production environments.

## Features

- ✅ Installs Vault from official HashiCorp repository
- ✅ Creates dedicated vault user and group
- ✅ Configures file-based storage backend
- ✅ Sets up systemd service for automatic startup
- ✅ Enables web UI for management
- ✅ Waits for Vault to be reachable after installation

## Prerequisites

### Control Machine
- Ansible 2.9+
- SSH access to target host(s)

### Target Host
- Ubuntu/Debian operating system
- SSH access with sudo privileges
- Internet access for downloading packages
- Port 8200 available

## Quick Start

### 1. Create Inventory File

```ini
[vault_servers]
vault.example.com ansible_user=your_username
```

### 2. Run the Playbook

```bash
ansible-playbook -i inventory.ini install_vault.yml
```

### 3. Initialize Vault

After installation, initialize Vault:

```bash
# SSH to the server
ssh vault.example.com

# Initialize Vault (save the unseal keys and root token!)
vault operator init

# Unseal Vault (use 3 of the 5 unseal keys)
vault operator unseal <key1>
vault operator unseal <key2>
vault operator unseal <key3>
```

### 4. Access Vault UI

Visit `http://vault.example.com:8200` and login with the root token.

## Configuration Details

### Installed Version
- **Vault**: 1.15.5 (pinned)

### File Locations

| Path | Purpose |
|------|---------|
| `/usr/local/bin/vault` | Vault binary |
| `/etc/vault.d/` | Configuration directory |
| `/etc/vault.d/vault.hcl` | Main configuration file |
| `/opt/vault/data/` | Data storage directory |
| `/etc/systemd/system/vault.service` | Systemd service file |

### Storage Configuration

The playbook configures file-based storage:

```hcl
storage "file" {
  path = "/opt/vault/data"
}
```

**Note**: File storage is suitable for development and small deployments. For production at scale, consider using Consul or other HA backends.

### Listener Configuration

```hcl
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
```

**Security Warning**: TLS is disabled by default for development. Enable TLS for production use.

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `vault_version` | `1.15.5` | Vault version to install |
| `vault_user` | `vault` | System user for Vault process |
| `vault_group` | `vault` | System group for Vault process |
| `vault_bin_path` | `/usr/local/bin/vault` | Vault binary location |
| `vault_config_path` | `/etc/vault.d` | Configuration directory |
| `vault_data_path` | `/opt/vault/data` | Data storage path |

## Post-Installation

### Initialize and Unseal

```bash
# Initialize
export VAULT_ADDR='http://vault.example.com:8200'
vault operator init -key-shares=5 -key-threshold=3

# Store unseal keys and root token securely!

# Unseal (repeat with 3 different keys)
vault operator unseal

# Check status
vault status
```

### Enable Authentication Methods

```bash
# Login with root token
vault login

# Enable userpass authentication
vault auth enable userpass

# Create a user
vault write auth/userpass/users/admin password=changeme policies=default
```

### Create Secrets

```bash
# Enable KV secrets engine
vault secrets enable -path=secret kv-v2

# Write a secret
vault kv put secret/myapp/config username=admin password=secret

# Read a secret
vault kv get secret/myapp/config
```

## Production Considerations

### Enable TLS

1. Obtain SSL certificates
2. Update listener configuration:

```hcl
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/etc/vault.d/vault.crt"
  tls_key_file  = "/etc/vault.d/vault.key"
}
```

3. Restart Vault: `sudo systemctl restart vault`

### High Availability

For HA setup:
- Use Consul or etcd as storage backend
- Deploy multiple Vault servers
- Configure load balancer
- Set up automatic unsealing (auto-unseal with cloud KMS)

### Backup Strategy

```bash
# Stop Vault
sudo systemctl stop vault

# Backup data directory
tar -czf vault-backup-$(date +%Y%m%d).tar.gz /opt/vault/data/

# Start Vault
sudo systemctl start vault
```

### Auto-Unseal

For production, configure auto-unseal with cloud KMS:

```hcl
seal "awskms" {
  region     = "us-east-1"
  kms_key_id = "your-kms-key-id"
}
```

## Troubleshooting

### Vault Won't Start

```bash
# Check service status
sudo systemctl status vault

# View logs
sudo journalctl -u vault -n 50

# Check configuration
vault operator diagnose
```

### Permission Errors

```bash
# Verify ownership
ls -la /opt/vault/data/
ls -la /etc/vault.d/

# Fix permissions if needed
sudo chown -R vault:vault /opt/vault/data/
sudo chown -R vault:vault /etc/vault.d/
```

### Cannot Access UI

- Verify Vault is running: `sudo systemctl status vault`
- Check firewall allows port 8200
- Verify Vault is initialized and unsealed

## Security Best Practices

- **Root Token**: Revoke after initial setup
- **Unseal Keys**: Store securely (split among team members)
- **TLS**: Always enable in production
- **Audit Logging**: Enable audit devices
- **Policies**: Use least-privilege access policies
- **Auto-Unseal**: Use cloud KMS for production
- **Backups**: Regular automated backups
- **Network**: Restrict access with firewall rules

## Integration Examples

### With Docker

```bash
docker run --rm -e VAULT_ADDR='http://vault.example.com:8200' \
  -e VAULT_TOKEN='s.xxxxx' vault/vault:latest \
  vault kv get secret/myapp/config
```

### With Terraform

```hcl
provider "vault" {
  address = "http://vault.example.com:8200"
  token   = var.vault_token
}

data "vault_generic_secret" "db_creds" {
  path = "secret/data/database"
}
```

## Additional Resources

- [Vault Documentation](https://www.vaultproject.io/docs)
- [Vault Getting Started](https://learn.hashicorp.com/vault)
- [Vault Production Hardening](https://learn.hashicorp.com/tutorials/vault/production-hardening)
- [Main Project README](../README.md)

## Support

For issues related to:
- **Vault Installation**: Check [Vault documentation](https://www.vaultproject.io/docs)
- **Ansible Playbooks**: See the [main project README](../README.md)
- **Vault Configuration**: Review [HashiCorp Learn](https://learn.hashicorp.com/vault)
