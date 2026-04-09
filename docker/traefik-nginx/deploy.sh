#!/usr/bin/env bash
# ─── Traefik + Nginx Bootstrap ───────────────────────
# Installs Ansible, prompts for config, deploys the full stack.
# Run on a vanilla Ubuntu VM:  sudo bash deploy.sh
set -euo pipefail

REPO_URL="https://github.com/jameskilbynet/iac.git"
REPO_DIR="/tmp/iac"
STACK_PATH="docker/traefik-nginx"

# ─── Colours ─────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─── Root Check ──────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)."
    exit 1
fi

# ─── OS Check ────────────────────────────────────────
if ! grep -qi 'ubuntu' /etc/os-release 2>/dev/null; then
    err "This script only supports Ubuntu."
    exit 1
fi

# ─── Prompt for Configuration ────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}  Traefik + Nginx Deployment${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

read -rp "Enter your domain name (e.g. example.com): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
    err "Domain name cannot be empty."
    exit 1
fi

read -rp "Enter the subdomain for the web server (e.g. vcf): " SUBDOMAIN
if [[ -z "$SUBDOMAIN" ]]; then
    err "Subdomain cannot be empty."
    exit 1
fi

read -rp "Enter your Cloudflare API token: " CF_TOKEN
if [[ -z "$CF_TOKEN" ]]; then
    err "Cloudflare API token cannot be empty."
    exit 1
fi

echo ""
info "Domain:     $DOMAIN"
info "Web server: ${SUBDOMAIN}.${DOMAIN}"
info "API Token:  ${CF_TOKEN:0:8}••••••••"
echo ""
read -rp "Proceed with deployment? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    info "Aborted."
    exit 0
fi

# ─── Install Git ─────────────────────────────────────
if ! command -v git &>/dev/null; then
    info "Installing git..."
    apt-get update -qq
    apt-get install -y -qq git
    ok "Git installed."
fi

# ─── Clone Repository ───────────────────────────────
if [[ -d "$REPO_DIR" ]]; then
    info "Updating existing repo..."
    git -C "$REPO_DIR" pull -q
else
    info "Cloning repository..."
    git clone -q "$REPO_URL" "$REPO_DIR"
fi
ok "Repository ready."

SCRIPT_DIR="${REPO_DIR}/${STACK_PATH}"

# ─── Install Ansible ─────────────────────────────────
if ! command -v ansible-playbook &>/dev/null; then
    info "Installing Ansible..."
    apt-get update -qq
    apt-get install -y -qq software-properties-common
    add-apt-repository -y --update ppa:ansible/ansible
    apt-get install -y -qq ansible
    ok "Ansible installed."
else
    ok "Ansible already installed."
fi

# ─── Run Playbook ────────────────────────────────────
info "Running deployment playbook..."
ansible-playbook \
    "${SCRIPT_DIR}/playbook.yml" \
    --extra-vars "domain=${DOMAIN} subdomain=${SUBDOMAIN} cf_dns_api_token=${CF_TOKEN}"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}  Deployment Complete${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo ""
echo "  Nginx:     https://${SUBDOMAIN}.${DOMAIN}"
echo "  Traefik:   https://traefik.${DOMAIN}"
echo "  Web root:  /vcf"
echo "  Stack dir: /opt/traefik-nginx"
echo ""
echo "  DNS: Point *.${DOMAIN} to this server's IP."
echo "  Certs will be issued automatically via Cloudflare DNS."
echo ""
