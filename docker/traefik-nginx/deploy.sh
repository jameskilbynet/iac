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

# ─── Disk Space Check ────────────────────────────────
# VCF offline depot payloads are large; fail fast if the root filesystem
# does not have enough free space for the download and extraction.
MIN_DISK_GB=100
AVAIL_GB=$(df -BG --output=avail / | tail -n1 | tr -dc '0-9')
if [[ -z "$AVAIL_GB" ]] || (( AVAIL_GB < MIN_DISK_GB )); then
    err "Insufficient disk space on /: ${AVAIL_GB:-unknown}GB available, ${MIN_DISK_GB}GB required."
    exit 1
fi
ok "Disk space check passed (${AVAIL_GB}GB available on /)."

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

read -rp "Enter the web server username: " WEB_USER
if [[ -z "$WEB_USER" ]]; then
    err "Username cannot be empty."
    exit 1
fi

read -rsp "Enter the web server password: " WEB_PASS
echo ""
if [[ -z "$WEB_PASS" ]]; then
    err "Password cannot be empty."
    exit 1
fi

read -rsp "Enter your Cloudflare API token: " CF_TOKEN
echo ""
if [[ -z "$CF_TOKEN" ]]; then
    err "Cloudflare API token cannot be empty."
    exit 1
fi

echo ""
info "Domain:     $DOMAIN"
info "Web server: ${SUBDOMAIN}.${DOMAIN}"
info "Auth user:  $WEB_USER"
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

# ─── Generate Basic Auth Hash ────────────────────────
info "Generating basic auth credentials..."
# Generate APR1 hash and escape $ for docker compose ($ becomes $$)
HTPASSWD_HASH=$(openssl passwd -apr1 "$WEB_PASS")
HTPASSWD_ESCAPED="${WEB_USER}:$(echo "$HTPASSWD_HASH" | sed 's/\$/\$\$/g')"
# Clear the plaintext password from memory as soon as possible
unset WEB_PASS
ok "Credentials generated."

# ─── Write Secrets to Temporary Vars File ────────────
# Using a vars file (mode 0600) instead of --extra-vars keeps secrets
# out of the process list where `ps aux` could otherwise reveal them.
VARS_FILE=$(mktemp)
chmod 600 "$VARS_FILE"
trap 'rm -f "$VARS_FILE"' EXIT INT TERM

cat > "$VARS_FILE" <<EOF
domain: "${DOMAIN}"
subdomain: "${SUBDOMAIN}"
cf_dns_api_token: "${CF_TOKEN}"
basicauth_users: "${HTPASSWD_ESCAPED}"
EOF

# Clear the plaintext token from the shell environment
unset CF_TOKEN HTPASSWD_HASH HTPASSWD_ESCAPED

# ─── Run Playbook ────────────────────────────────────
info "Running deployment playbook..."
ansible-playbook \
    "${SCRIPT_DIR}/playbook.yml" \
    --extra-vars "@${VARS_FILE}"

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
