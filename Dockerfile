# Use Node.js Alpine for much smaller image size
FROM node:18-alpine

ENV ANTHROPIC_API_KEY=""
ENV GITHUB_TOKEN=""
ENV TARGET_REPO=""

# Install system dependencies and GitHub CLI
RUN apk add --no-cache \
    git \
    bash \
    curl \
    wget \
    ca-certificates \
    github-cli

# Install Claude CLI via npm
RUN npm install -g @anthropic-ai/claude-code

# Create working directory
WORKDIR /app

# Copy the repository content
COPY . .

# Set up git configuration (will be overridden by environment variables)
RUN git config --global user.name "GitHub Agent" \
    && git config --global user.email "agent@github.com" \
    && git config --global init.defaultBranch main

# Create the agent script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Configure git with environment variables if provided\n\
if [ ! -z "$GIT_USER_NAME" ]; then\n\
    git config --global user.name "$GIT_USER_NAME"\n\
fi\n\
\n\
if [ ! -z "$GIT_USER_EMAIL" ]; then\n\
    git config --global user.email "$GIT_USER_EMAIL"\n\
fi\n\
\n\
# Authenticate GitHub CLI\n\
if [ -z "$GITHUB_TOKEN" ]; then\n\
    echo "Error: GITHUB_TOKEN environment variable is required"\n\
    exit 1\n\
fi\n\
\n\
echo "$GITHUB_TOKEN" | gh auth login --with-token\n\
\n\
# Clone or update the target repository\n\
if [ -z "$TARGET_REPO" ]; then\n\
    echo "Error: TARGET_REPO environment variable is required (format: owner/repo)"\n\
    exit 1\n\
fi\n\
\n\
REPO_DIR="/workspace/$(basename $TARGET_REPO)"\n\
\n\
if [ -d "$REPO_DIR" ]; then\n\
    echo "Repository directory exists, updating..."\n\
    cd "$REPO_DIR"\n\
    git fetch origin\n\
    git reset --hard origin/main || git reset --hard origin/master\n\
else\n\
    echo "Cloning repository..."\n\
    mkdir -p /workspace\n\
    cd /workspace\n\
    gh repo clone "$TARGET_REPO"\n\
    cd "$(basename $TARGET_REPO)"\n\
fi\n\
\n\
# Check if Anthropic API key is set\n\
if [ -z "$ANTHROPIC_API_KEY" ]; then\n\
    echo "Error: ANTHROPIC_API_KEY environment variable is required"\n\
    exit 1\n\
fi\n\
\n\
# Run Claude with the instructions\n\
echo "Starting GitHub agent..."\n\
claude --non-interactive < /app/CLAUDE_INSTRUCTIONS.md\n\
' > /app/run_agent.sh && chmod +x /app/run_agent.sh

# Create a health check script
RUN echo '#!/bin/bash\n\
# Simple health check - verify required tools are available\n\
claude --version > /dev/null 2>&1 && \\\n\
gh --version > /dev/null 2>&1 && \\\n\
git --version > /dev/null 2>&1 && \\\n\
echo "Health check passed" || echo "Health check failed"\n\
' > /app/health_check.sh && chmod +x /app/health_check.sh

# Set the default command
CMD ["/app/run_agent.sh"]

# Add labels for better Docker image management
LABEL maintainer="GitHub Agent"
LABEL description="Automated GitHub repository agent using Claude CLI"
LABEL version="1.0"