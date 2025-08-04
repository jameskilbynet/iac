#!/bin/bash
# -----------------------------------------------------------------------------
# MIT License
# 
# Copyright (c) 2025 Christian Mohn
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# -----------------------------------------------------------------------------

# --- Versioning ---
SCRIPT_VERSION="1.2.0"

# --- Show version and exit if requested ---
if [[ "$1" == "--version" || "$1" == "-v" ]]; then
  echo "Portainer Inventory Script Version: v$SCRIPT_VERSION"
  exit 0
fi

echo "Portainer Inventory Script v$SCRIPT_VERSION"

# --- Load environment variables ---
if [[ -f .env ]]; then
  echo "Loading environment variables from .env"
  source .env
else
  echo "Error: .env file not found. Please create one with PORTAINER_URL, USERNAME, and PASSWORD."
  exit 1
fi

# --- Configuration ---
OUTPUT_FILE="portainer-inventory.md"
CURRENT_DATE=$(date '+%d/%m/%Y')

# --- Authenticate and get JWT token ---
echo "Authenticating with Portainer..."

AUTH_RESPONSE=$(curl -s -X POST "$PORTAINER_URL/auth" \
  -H "Content-Type: application/json" \
  -d "{\"Username\":\"$USERNAME\",\"Password\":\"$PASSWORD\"}")

TOKEN=$(echo "$AUTH_RESPONSE" | jq -r .jwt)

if [[ "$TOKEN" == "null" || -z "$TOKEN" ]]; then
  echo "Authentication failed:"
  echo "$AUTH_RESPONSE"
  exit 1
fi

echo "Authenticated successfully."

# --- Get all endpoints ---
echo "Fetching all endpoints..."

ENDPOINTS=$(curl -s -X GET "$PORTAINER_URL/endpoints" \
  -H "Authorization: Bearer $TOKEN")

# --- Get all stacks ---
echo "Fetching all stacks..."

STACKS=$(curl -s -X GET "$PORTAINER_URL/stacks" \
  -H "Authorization: Bearer $TOKEN")

# --- Start Markdown Output ---
> "$OUTPUT_FILE"

# --- Include optional custom header if exists ---
HEADER_FILE="templates/header.md"
if [[ -f "$HEADER_FILE" ]]; then
  echo "Found header template: $HEADER_FILE"
  cat "$HEADER_FILE" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
else
  echo "No custom header file found."
fi

# --- Always include standard header info ---
echo "# Portainer Inventory Report" >> "$OUTPUT_FILE"
echo "Generated on ${CURRENT_DATE}" >> "$OUTPUT_FILE"
echo "Script version: v${SCRIPT_VERSION}" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# --- Iterate over each endpoint ---
echo "$ENDPOINTS" | jq -c '.[]' | while read -r endpoint; do
  ENDPOINT_ID=$(echo "$endpoint" | jq -r .Id)
  ENDPOINT_NAME=$(echo "$endpoint" | jq -r .Name)

  echo "Processing environment: $ENDPOINT_NAME (ID: $ENDPOINT_ID)"

  echo "## Environment: $ENDPOINT_NAME (ID: $ENDPOINT_ID)" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"

  # --- Get containers for this endpoint ---
  CONTAINERS=$(curl -s -X GET \
    "$PORTAINER_URL/endpoints/$ENDPOINT_ID/docker/containers/json?all=true" \
    -H "Authorization: Bearer $TOKEN")

  # --- Filter stacks for this endpoint ---
  STACKS_FOR_ENDPOINT=$(echo "$STACKS" | jq -c --argjson eid "$ENDPOINT_ID" '.[] | select(.EndpointID == $eid)')
  STACK_IDS=$(echo "$STACKS_FOR_ENDPOINT" | jq -r '.Id')

  if [[ -z "$STACK_IDS" ]]; then
    echo "_No stacks found for this environment._" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
  fi

  for STACK_ID in $STACK_IDS; do
    STACK_JSON=$(echo "$STACKS_FOR_ENDPOINT" | jq -c "select(.Id == $STACK_ID)")
    STACK_NAME=$(echo "$STACK_JSON" | jq -r .Name)
    STACK_TYPE=$(echo "$STACK_JSON" | jq -r .Type)
    STACK_STATUS=$(echo "$STACK_JSON" | jq -r .Status)

    echo "### Stack: $STACK_NAME" >> "$OUTPUT_FILE"
    echo "- **ID:** $STACK_ID" >> "$OUTPUT_FILE"
    echo "- **Type:** $STACK_TYPE" >> "$OUTPUT_FILE"
    echo "- **Status:** $STACK_STATUS" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    for STATE in "running" "stopped"; do
      if [[ "$STATE" == "running" ]]; then
        LABEL="Running Containers"
      else
        LABEL="Stopped Containers"
      fi

      CONTAINERS_MATCHING=$(echo "$CONTAINERS" | jq -c --arg state "$STATE" --arg stack "$STACK_NAME" '
        .[] |
        select(.Labels["com.docker.stack.namespace"] == $stack) |
        select((.State == $state) or ($state == "stopped" and .State != "running"))')

      if [[ -z "$CONTAINERS_MATCHING" ]]; then
        continue
      fi

      echo "#### $LABEL" >> "$OUTPUT_FILE"
      echo "" >> "$OUTPUT_FILE"
      echo "| Name | Image | Status | Ports | Environment | ID | Volumes | Networks |" >> "$OUTPUT_FILE"
      echo "|------|-------|--------|-------|-------------|----|---------|----------|" >> "$OUTPUT_FILE"

      echo "$CONTAINERS_MATCHING" | jq -c '.' | while read -r container; do
        CONTAINER_ID=$(echo "$container" | jq -r .Id)
        NAME=$(echo "$container" | jq -r '.Names[0]' | sed 's|/||')
        IMAGE=$(echo "$container" | jq -r .Image)
        STATUS=$(echo "$container" | jq -r .State)
        ID_SHORT=$(echo "$CONTAINER_ID" | cut -c1-12)
        PORTS=$(echo "$container" | jq -r '[.Ports[]? | "\(.PublicPort):\(.PrivatePort)/\(.Type)"] | join(", ")')
        [[ -z "$PORTS" || "$PORTS" == "-" ]] && PORTS="(none)"

        # Fetch detailed container info for volumes and networks
        DETAIL=$(curl -s -X GET \
          "$PORTAINER_URL/endpoints/$ENDPOINT_ID/docker/containers/$CONTAINER_ID/json" \
          -H "Authorization: Bearer $TOKEN")

        VOLUMES=$(echo "$DETAIL" | jq -r '[.Mounts[]? | .Destination] | join(", ")')
        [[ -z "$VOLUMES" ]] && VOLUMES="(none)"

        NETWORKS=$(echo "$DETAIL" | jq -r '.NetworkSettings.Networks | keys | join(", ")')
        [[ -z "$NETWORKS" ]] && NETWORKS="(none)"

        echo "| $NAME | $IMAGE | $STATUS | $PORTS | $ENDPOINT_NAME | $ID_SHORT | $VOLUMES | $NETWORKS |" >> "$OUTPUT_FILE"
      done

      echo "" >> "$OUTPUT_FILE"
    done
  done

  # --- Orphan containers ---
  echo "## Orphan Containers (Not in Any Stack)" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"

  for STATE in "running" "stopped"; do
    if [[ "$STATE" == "running" ]]; then
      LABEL="Running Containers"
    else
      LABEL="Stopped Containers"
    fi

    CONTAINERS_MATCHING=$(echo "$CONTAINERS" | jq -c --arg state "$STATE" '
      .[] |
      select(.Labels["com.docker.stack.namespace"] == null) |
      select((.State == $state) or ($state == "stopped" and .State != "running"))')

    if [[ -z "$CONTAINERS_MATCHING" ]]; then
      continue
    fi

    echo "### $LABEL" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "| Name | Image | Status | Ports | Environment | ID | Volumes | Networks |" >> "$OUTPUT_FILE"
    echo "|------|-------|--------|-------|-------------|----|---------|----------|" >> "$OUTPUT_FILE"

    echo "$CONTAINERS_MATCHING" | jq -c '.' | while read -r container; do
      CONTAINER_ID=$(echo "$container" | jq -r .Id)
      NAME=$(echo "$container" | jq -r '.Names[0]' | sed 's|/||')
      IMAGE=$(echo "$container" | jq -r .Image)
      STATUS=$(echo "$container" | jq -r .State)
      ID_SHORT=$(echo "$CONTAINER_ID" | cut -c1-12)
      PORTS=$(echo "$container" | jq -r '[.Ports[]? | "\(.PublicPort):\(.PrivatePort)/\(.Type)"] | join(", ")')
      [[ -z "$PORTS" || "$PORTS" == "-" ]] && PORTS="(none)"

      # Fetch detailed container info for volumes and networks
      DETAIL=$(curl -s -X GET \
        "$PORTAINER_URL/endpoints/$ENDPOINT_ID/docker/containers/$CONTAINER_ID/json" \
        -H "Authorization: Bearer $TOKEN")

      VOLUMES=$(echo "$DETAIL" | jq -r '[.Mounts[]? | .Destination] | join(", ")')
      [[ -z "$VOLUMES" ]] && VOLUMES="(none)"

      NETWORKS=$(echo "$DETAIL" | jq -r '.NetworkSettings.Networks | keys | join(", ")')
      [[ -z "$NETWORKS" ]] && NETWORKS="(none)"

      echo "| $NAME | $IMAGE | $STATUS | $PORTS | $ENDPOINT_NAME | $ID_SHORT | $VOLUMES | $NETWORKS |" >> "$OUTPUT_FILE"
    done

    echo "" >> "$OUTPUT_FILE"
  done

  echo "---" >> "$OUTPUT_FILE"
done

echo "Inventory saved to $OUTPUT_FILE"