# NVIDIA vGPU Ansible Playbooks

This directory contains Ansible playbooks for installing and configuring NVIDIA vGPU drivers and container toolkit on Ubuntu hosts.

## Overview

Four playbooks work together to set up and validate NVIDIA vGPU capabilities:

1. **install_nvidia_drivers.yml** - Installs NVIDIA vGPU drivers and licensing
2. **install_nvidia_containertoolkit.yml** - Installs NVIDIA Container Toolkit for Docker GPU support
3. **test_nvidia_container.yml** - Tests GPU access in Docker containers
4. **validate_nvidia_vGPU.yml** - Validates vGPU licensing and driver status

## Prerequisites

- Ubuntu Linux hosts with vGPU capability
- Ansible control node with SSH access to target hosts
- NFS share accessible at `nas.jameskilby.cloud:/mnt/pool1/ISO/nvidia` containing:
  - NVIDIA vGPU driver file: `NVIDIA-Linux-x86_64-535.247.01-grid.run`
  - License token file: `client_configuration_token_04-08-2025-16-54-19.tok`
- Docker installed on target hosts (for container toolkit playbook)

## Playbook 1: install_nvidia_drivers.yml

### Purpose

Installs NVIDIA vGPU drivers, configures licensing, and validates the installation.

### What It Does

1. Installs required build tools and kernel headers
2. Mounts NFS share containing NVIDIA driver files
3. Checks if NVIDIA drivers are already installed (idempotent)
4. Copies and installs the NVIDIA vGPU driver silently
5. Deploys the license token to `/etc/nvidia/ClientConfigToken/`
6. Starts and enables the `nvidia-gridd` licensing daemon
7. Validates that the GPU is properly licensed

### Variables

You can override these in your inventory or via `--extra-vars`:

```yaml
nvidia_driver_file: NVIDIA-Linux-x86_64-535.247.01-grid.run
nvidia_licence_file: client_configuration_token_04-08-2025-16-54-19.tok
nfs_server: nas.jameskilby.cloud
nfs_export_path: /mnt/pool1/ISO/nvidia
nfs_mount_point: /mnt/iso/nvidia
```

### Usage

```bash
# Run against all hosts
ansible-playbook -i inventory install_nvidia_drivers.yml

# Run against specific host
ansible-playbook -i inventory install_nvidia_drivers.yml --limit hostname

# Override variables
ansible-playbook -i inventory install_nvidia_drivers.yml \
  --extra-vars "nvidia_driver_file=NVIDIA-Linux-x86_64-xxx.run"
```

### Post-Installation

After successful installation, `nvidia-smi` should show licensed vGPU(s). The playbook will fail if the license check shows "Unlicensed".

## Playbook 2: install_nvidia_containertoolkit.yml

### Purpose

Installs the NVIDIA Container Toolkit to enable GPU access for Docker containers.

### What It Does

1. Installs required packages (curl, gpg, ca-certificates)
2. Adds NVIDIA Container Toolkit repository with proper GPG signing
3. Installs `nvidia-container-toolkit` package
4. Configures Docker to use the NVIDIA runtime
5. Restarts Docker service to apply configuration
6. Starts the `nvidia-gridd` licensing daemon
7. Validates GPU access by running `nvidia-smi` inside a test container

### Usage

```bash
# Run against all hosts
ansible-playbook -i inventory install_nvidia_containertoolkit.yml

# Run against specific host
ansible-playbook -i inventory install_nvidia_containertoolkit.yml --limit hostname
```

### Validation

The playbook runs a test container to verify GPU access:

```bash
docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
```

If successful, you'll see the nvidia-smi output showing available GPUs.

## Playbook 3: test_nvidia_container.yml

### Purpose

Tests NVIDIA Container Toolkit functionality by running nvidia-smi inside a Docker container.

### What It Does

1. Runs `docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi`
2. Captures and displays the output
3. Fails if the command returns a non-zero exit code

### Usage

```bash
ansible-playbook -i inventory test_nvidia_container.yml
```

## Playbook 4: validate_nvidia_vGPU.yml

### Purpose

Validates that NVIDIA vGPU drivers are properly installed, licensed, and functional.

### What It Does

1. Checks if `/var/lib/nvidia/licensing/` directory exists
2. Verifies presence of `.tok` license token file
3. Confirms `nvidia-gridd` service is active
4. Checks license status via `nvidia-smi -q`
5. Fails if vGPU is unlicensed

### Usage

```bash
ansible-playbook -i inventory validate_nvidia_vGPU.yml
```

## Running All Playbooks

For a complete setup and validation on a new host, run all playbooks in order:

```bash
# 1. Install drivers first
ansible-playbook -i inventory install_nvidia_drivers.yml

# 2. Install container toolkit
ansible-playbook -i inventory install_nvidia_containertoolkit.yml

# 3. Test container GPU access
ansible-playbook -i inventory test_nvidia_container.yml

# 4. Validate licensing
ansible-playbook -i inventory validate_nvidia_vGPU.yml
```

## Using Docker with GPU

After installation, you can run containers with GPU access:

```bash
# Run with all GPUs
docker run --rm --runtime=nvidia --gpus all nvidia/cuda:12.0-base nvidia-smi

# Run with specific GPU
docker run --rm --runtime=nvidia --gpus device=0 nvidia/cuda:12.0-base nvidia-smi

# Docker Compose example
services:
  gpu-app:
    image: nvidia/cuda:12.0-base
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
```

## Troubleshooting

### Driver Installation Issues

Check if drivers loaded:
```bash
lsmod | grep nvidia
```

View driver installation logs:
```bash
cat /var/log/nvidia-installer.log
```

### License Issues

Check nvidia-gridd service:
```bash
systemctl status nvidia-gridd
journalctl -u nvidia-gridd -f
```

View license status:
```bash
nvidia-smi -q | grep -i license
```

### Container Toolkit Issues

Verify Docker configuration:
```bash
cat /etc/docker/daemon.json
```

Test GPU access:
```bash
docker run --rm --runtime=nvidia --gpus all nvidia/cuda:12.0-base nvidia-smi
```

Check Docker daemon logs:
```bash
journalctl -u docker -f
```

## Notes

- The driver installation playbook is idempotent - it checks if drivers are already installed
- Both playbooks require root/sudo access (`become: yes/true`)
- NFS mount uses optimized settings for large file transfers
- The driver installer runs with `--silent --no-cc-version-check` flags
- A 30-second pause is included after starting nvidia-gridd to allow license activation

## Files Created/Modified

### Driver Playbook
- `/etc/nvidia/ClientConfigToken/` - License token directory
- `/usr/bin/nvidia-smi` - NVIDIA management tool
- `/etc/systemd/system/nvidia-gridd.service` - Licensing daemon

### Container Toolkit Playbook
- `/etc/docker/daemon.json` - Docker runtime configuration
- `/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg` - Repository GPG key
- `/etc/apt/sources.list.d/nvidia-container-toolkit.list` - APT repository
