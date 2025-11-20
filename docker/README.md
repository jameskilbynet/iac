# Docker Projects

This directory contains Docker-based projects and configurations for containerized applications.

## Overview

A collection of Docker projects that integrate with the parent IAC repository's infrastructure automation capabilities.

## Getting Started

### Prerequisites

- Docker (>= 20.10.0)
- Docker Compose (>= 2.0.0)

### Directory Structure

Each subdirectory should contain:
- `Dockerfile` - Container image definition
- `docker-compose.yml` - Multi-container orchestration (if needed)
- `.env.example` - Example environment variables
- `README.md` - Project-specific documentation

## Usage

Navigate to individual project directories and follow their respective README files.

## Integration

This directory integrates with:
- **Ansible**: `../ansible/docker/` for Docker installation
- **Ansible**: `../ansible/portainer/` for Portainer agent deployment
- **Terraform**: `../terraform/` for VM infrastructure provisioning

## Security

- Never commit `.env` files or secrets
- Use `.env.example` to document required variables
- Store sensitive data in environment variables or Docker secrets

## Contributing

When adding new Docker projects:
1. Create a descriptive subdirectory
2. Include comprehensive README
3. Provide `.env.example` if environment variables are needed
4. Document resource requirements and dependencies
