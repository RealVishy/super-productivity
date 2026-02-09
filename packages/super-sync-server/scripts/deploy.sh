#!/bin/bash
# SuperSync Server Deployment Script
#
# Usage:
#   ./scripts/deploy.sh
#
# This script:
#   1. Builds the server image locally from source
#   2. Restarts containers
#   3. Verifies health check passes

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(dirname "$SCRIPT_DIR")"

# Get domain from .env file
if [ -f "$SERVER_DIR/.env" ]; then
    DOMAIN=$(grep -E '^DOMAIN=' "$SERVER_DIR/.env" | cut -d'=' -f2)
fi

if [ -z "$DOMAIN" ]; then
    echo "Warning: DOMAIN not set in .env, using localhost for health check"
    HEALTH_URL="http://localhost:1900/health"
else
    HEALTH_URL="https://$DOMAIN/health"
fi

echo "==> SuperSync Deployment"
echo "    Server dir: $SERVER_DIR"
echo "    Health URL: $HEALTH_URL"
echo ""

cd "$SERVER_DIR"

# Check if monitoring compose exists and include it
COMPOSE_FILES="-f docker-compose.yml"
if [ -f "docker-compose.monitoring.yml" ]; then
    COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.monitoring.yml"
fi

echo "==> Building and starting..."
docker compose $COMPOSE_FILES up -d --build

# Wait for health check
echo ""
echo "==> Waiting for service to be healthy..."
sleep 5

# Retry health check up to 6 times (30 seconds total)
for i in {1..6}; do
    if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
        echo ""
        echo "==> Deployment successful!"
        echo "    Service is healthy at $HEALTH_URL"
        exit 0
    fi
    echo "    Waiting... (attempt $i/6)"
    sleep 5
done

echo ""
echo "==> Health check failed!"
echo "    Recent logs:"
docker compose logs --tail=30 supersync
exit 1
