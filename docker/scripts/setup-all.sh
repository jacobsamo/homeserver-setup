#!/bin/bash

# setup-all.sh: Script to set up and start all Docker stacks in order.
# Creates the proxy network if it doesn't exist and starts stacks sequentially.

set -e  # Exit on errors

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Homeserver Setup Script ==="
echo "Docker directory: $DOCKER_DIR"
echo ""

# Create proxy network if it doesn't exist
echo "Checking for proxy network..."
if ! docker network ls | grep -q "proxy"; then
    docker network create proxy
    echo "Docker network 'proxy' created."
else
    echo "Docker network 'proxy' already exists."
fi
echo ""

# Function to start a stack
start_stack() {
    local stack_name=$1
    local stack_path="$DOCKER_DIR/$stack_name"

    if [ -d "$stack_path" ] && [ -f "$stack_path/docker-compose.yml" ]; then
        echo "Starting $stack_name stack..."
        docker compose -f "$stack_path/docker-compose.yml" up -d
        echo "$stack_name stack started."
    else
        echo "Warning: $stack_name stack not found or missing docker-compose.yml, skipping."
    fi
    echo ""
}

# Start stacks in order
echo "=== Starting Stacks ==="
echo ""

start_stack "proxy"
start_stack "management"
start_stack "apps"
start_stack "monitoring"
start_stack "games"

echo "=== All stacks started! ==="
echo ""
echo "To check status, run: docker ps"
echo "To view logs, run: docker compose -f <stack>/docker-compose.yml logs -f"
