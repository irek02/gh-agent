#!/bin/bash

echo "=== GitHub Agent Local Test ==="
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found."
    echo "Please create .env file with your credentials:"
    echo ""
    echo "cp .env.example .env"
    echo "# Then edit .env with your actual values"
    echo ""
    exit 1
fi

# Load environment variables
set -o allexport
source .env
set +o allexport

# Validate required environment variables
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "❌ Error: ANTHROPIC_API_KEY not set in .env file"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Error: GITHUB_TOKEN not set in .env file"
    exit 1
fi

if [ -z "$TARGET_REPO" ]; then
    echo "❌ Error: TARGET_REPO not set in .env file"
    exit 1
fi

echo "✅ Environment variables loaded:"
echo "   TARGET_REPO: $TARGET_REPO"
echo "   ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:0:8}..."
echo "   GITHUB_TOKEN: ${GITHUB_TOKEN:0:8}..."
echo ""

echo "🐳 Running GitHub Agent in Docker container..."
echo "   This will:"
echo "   1. Clone/update the target repository"
echo "   2. Check for open issues and PRs"
echo "   3. Take action based on the instructions"
echo ""

# Run the Docker container with environment variables
docker run --rm \
    -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
    -e GITHUB_TOKEN="$GITHUB_TOKEN" \
    -e TARGET_REPO="$TARGET_REPO" \
    -e GIT_USER_NAME="${GIT_USER_NAME:-GitHub Agent}" \
    -e GIT_USER_EMAIL="${GIT_USER_EMAIL:-agent@github.com}" \
    -v github-agent-workspace:/workspace \
    github-agent

echo ""
echo "🏁 Agent execution completed!"