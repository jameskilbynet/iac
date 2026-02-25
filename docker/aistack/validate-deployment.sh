#!/bin/bash

# AI Stack Deployment Validation Script
# This script validates the health and configuration of the AI stack deployment

set -e

COMPOSE_FILE="${1:-docker-compose.yml}"

echo "========================================="
echo "AI Stack Deployment Validation"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored status
print_status() {
    if [ "$1" == "OK" ]; then
        echo -e "${GREEN}✓${NC} $2"
    elif [ "$1" == "WARN" ]; then
        echo -e "${YELLOW}⚠${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# Check if docker-compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    print_status "FAIL" "docker-compose.yml not found!"
    exit 1
fi
print_status "OK" "Found docker-compose.yml"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_status "FAIL" "Docker is not running"
    exit 1
fi
print_status "OK" "Docker daemon is running"

# Check if services are running
echo ""
echo "Service Status:"
echo "---------------"

SERVICES=("aistack-ollama" "aistack-open-webui" "aistack-comfyui" "aistack-whishper"
          "aistack-qdrant" "aistack-tika" "aistack-searxng" "aistack-otel-collector"
          "aistack-jaeger" "aistack-prometheus" "aistack-grafana")

ALL_RUNNING=true
for service in "${SERVICES[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
        STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$service" 2>/dev/null || echo "no healthcheck")
        if [ "$STATUS" == "healthy" ]; then
            print_status "OK" "$service (healthy)"
        elif [ "$STATUS" == "no healthcheck" ]; then
            print_status "WARN" "$service (running, no healthcheck)"
        else
            print_status "FAIL" "$service (unhealthy: $STATUS)"
            ALL_RUNNING=false
        fi
    else
        print_status "FAIL" "$service (not running)"
        ALL_RUNNING=false
    fi
done

# Check network configuration
echo ""
echo "Network Configuration:"
echo "----------------------"

if docker network ls | grep -q "aistack-internal"; then
    print_status "OK" "aistack-internal network exists"
else
    print_status "FAIL" "aistack-internal network not found"
fi

if docker network ls | grep -q "traefik"; then
    print_status "OK" "traefik network exists"
else
    print_status "WARN" "traefik network not found (required for external access)"
fi

# Check volumes
echo ""
echo "Volume Configuration:"
echo "---------------------"

VOLUMES=("ollama_models" "openwebui_data" "comfyui_data" "qdrant_storage"
         "jaeger_data" "prometheus_data" "grafana_data")

for volume in "${VOLUMES[@]}"; do
    FULL_NAME="aistack_${volume}"
    if docker volume ls | grep -q "$FULL_NAME"; then
        SIZE=$(docker volume inspect "$FULL_NAME" --format '{{.Name}}' 2>/dev/null)
        print_status "OK" "$volume exists"
    else
        print_status "WARN" "$volume not found (will be created on startup)"
    fi
done

# Check resource limits
echo ""
echo "Resource Configuration:"
echo "-----------------------"

check_resource_limits() {
    SERVICE=$1
    CONTAINER=$(docker ps --format '{{.Names}}' | grep "^aistack-${SERVICE}$" || echo "")

    if [ -n "$CONTAINER" ]; then
        MEM_LIMIT=$(docker inspect "$CONTAINER" --format='{{.HostConfig.Memory}}' 2>/dev/null || echo "0")
        CPU_LIMIT=$(docker inspect "$CONTAINER" --format='{{.HostConfig.NanoCpus}}' 2>/dev/null || echo "0")

        if [ "$MEM_LIMIT" != "0" ] && [ "$CPU_LIMIT" != "0" ]; then
            MEM_GB=$(awk "BEGIN {printf \"%.1f\", $MEM_LIMIT/1024/1024/1024}")
            CPU_COUNT=$(awk "BEGIN {printf \"%.1f\", $CPU_LIMIT/1000000000}")
            print_status "OK" "$SERVICE: ${MEM_GB}G RAM, ${CPU_COUNT} CPUs"
        else
            print_status "WARN" "$SERVICE: No resource limits set"
        fi
    fi
}

check_resource_limits "ollama"
check_resource_limits "open-webui"
check_resource_limits "prometheus"

# Check environment variables
echo ""
echo "Environment Configuration:"
echo "--------------------------"

if [ -f ".env" ]; then
    print_status "OK" ".env file exists"

    # Check critical variables
    if grep -q "OLLAMA_API_CREDENTIALS=" .env; then
        print_status "OK" "OLLAMA_API_CREDENTIALS set"
    else
        print_status "WARN" "OLLAMA_API_CREDENTIALS not set"
    fi

    if grep -q "SEARXNG_SECRET=" .env; then
        print_status "OK" "SEARXNG_SECRET set"
    else
        print_status "WARN" "SEARXNG_SECRET not set"
    fi

    if grep -q "GRAFANA_ADMIN_PASSWORD=" .env; then
        print_status "OK" "GRAFANA_ADMIN_PASSWORD set"
    else
        print_status "WARN" "GRAFANA_ADMIN_PASSWORD not set"
    fi
else
    print_status "FAIL" ".env file not found"
fi

# Check if Ollama API is accessible
echo ""
echo "Service Accessibility:"
echo "----------------------"

if docker ps --format '{{.Names}}' | grep -q "^aistack-ollama$"; then
    if docker exec aistack-ollama ollama list > /dev/null 2>&1; then
        print_status "OK" "Ollama API is responding"
        echo "   Available models:"
        docker exec aistack-ollama ollama list | tail -n +2 | awk '{print "     - " $1}' || true
    else
        print_status "WARN" "Ollama API not responding yet"
    fi
fi

# Check Prometheus targets (if running)
if docker ps --format '{{.Names}}' | grep -q "^aistack-prometheus$"; then
    TARGET_COUNT=$(docker exec aistack-prometheus wget -qO- http://localhost:9090/api/v1/targets 2>/dev/null | grep -o '"up"' | wc -l || echo "0")
    if [ "$TARGET_COUNT" -gt "0" ]; then
        print_status "OK" "Prometheus has $TARGET_COUNT active targets"
    else
        print_status "WARN" "Prometheus has no active targets"
    fi
fi

# Summary
echo ""
echo "========================================="
echo "Validation Summary"
echo "========================================="

if $ALL_RUNNING; then
    print_status "OK" "All services are running"
    echo ""
    echo "Access URLs:"
    echo "  - Open WebUI: https://chat.example.com"
    echo "  - Ollama API: https://ollama.example.com"
    echo "  - Grafana: https://grafana.example.com"
    echo "  - Prometheus: https://prometheus.example.com"
    echo "  - Jaeger: https://jaeger.example.com"
else
    print_status "WARN" "Some services are not running or unhealthy"
    echo ""
    echo "Check logs with: docker compose logs -f [service-name]"
fi

echo ""
echo "Resource usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep "^aistack-" || true

echo ""