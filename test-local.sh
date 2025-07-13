#!/bin/bash

# Local testing script for GitHub Agent Docker container
set -e

echo "=== GitHub Agent Local Test ==="

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found. Please copy .env.example to .env and configure it."
    exit 1
fi

# Source environment variables
set -o allexport
source .env
set +o allexport

# Validate required environment variables
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "Error: ANTHROPIC_API_KEY not set in .env file"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN not set in .env file"
    exit 1
fi

if [ -z "$TARGET_REPO" ]; then
    echo "Error: TARGET_REPO not set in .env file"
    exit 1
fi

echo "Building Docker image..."
docker build -t github-agent .

echo "Running health check..."
docker run --rm github-agent /app/health_check.sh

echo "Running single test execution (dry run)..."
docker run --rm \
    -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
    -e GITHUB_TOKEN="$GITHUB_TOKEN" \
    -e TARGET_REPO="$TARGET_REPO" \
    -e GIT_USER_NAME="${GIT_USER_NAME:-GitHub Agent}" \
    -e GIT_USER_EMAIL="${GIT_USER_EMAIL:-agent@github.com}" \
    github-agent

echo "Test completed!"
echo ""
echo "To run with Docker Compose (continuous mode):"
echo "  docker-compose up -d"
echo ""
echo "To view logs:"
echo "  docker-compose logs -f"