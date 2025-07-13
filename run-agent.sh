#!/bin/bash

# GitHub Agent Runner Script
# This script periodically executes Claude CLI with the GitHub automation instructions

set -e

# Configuration
REPO_PATH="$(pwd)"
TARGET_REPO="irek02/hello-world-docker"  # Will be set via command line or use current directory
INSTRUCTIONS_FILE="$REPO_PATH/CLAUDE_INSTRUCTIONS_SIMPLE.md"
LOG_FILE="$REPO_PATH/agent.log"
INTERVAL_SECONDS=300  # 5 minutes

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to run Claude CLI session
run_claude_session() {
    log "Starting Claude CLI automation session"

    # Change to repository directory
    cd "$REPO_PATH"

    # Prepare instructions with target repository context
    local instructions="$(cat "$INSTRUCTIONS_FILE")"
    if [ -n "$TARGET_REPO" ]; then
        instructions="Target Repository: $TARGET_REPO

All GitHub CLI commands should use --repo $TARGET_REPO flag.

$instructions"
    fi

    # Run Claude CLI with instructions and skip permissions for automation
    claude --print --dangerously-skip-permissions "$instructions" 2>&1 | tee -a "$LOG_FILE"

    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        log "Claude session completed successfully"
    else
        log "Claude session failed with exit code $exit_code"
    fi

    return $exit_code
}

# Function to check prerequisites
check_prerequisites() {
    # Check if Claude CLI is available
    if ! command -v claude &> /dev/null; then
        log "ERROR: Claude CLI not found. Please install Claude CLI first."
        exit 1
    fi

    # Check if gh CLI is available
    if ! command -v gh &> /dev/null; then
        log "ERROR: GitHub CLI (gh) not found. Please install gh CLI first."
        exit 1
    fi

    # Check if instructions file exists
    if [ ! -f "$INSTRUCTIONS_FILE" ]; then
        log "ERROR: Instructions file not found: $INSTRUCTIONS_FILE"
        exit 1
    fi

    # Check if we have the necessary GitHub labels
    log "Ensuring required GitHub labels exist..."
    gh label create "bot-working" --description "Issue is being worked on by the bot" --color "fbca04" 2>/dev/null || true
    gh label create "bot-completed" --description "Issue was completed by the bot" --color "0e8a16" 2>/dev/null || true
    gh label create "bot-skipped" --description "Issue was skipped by the bot" --color "d73a49" 2>/dev/null || true

    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log "ERROR: Not in a git repository"
        exit 1
    fi

    log "Prerequisites check passed"
}

# Function to handle cleanup on exit
cleanup() {
    log "Agent runner stopping..."
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main execution
main() {
    log "GitHub Agent Runner starting..."
    log "Repository: $REPO_PATH"
    log "Interval: $INTERVAL_SECONDS seconds"
    log "Instructions: $INSTRUCTIONS_FILE"

    check_prerequisites

    while true; do
        run_claude_session || log "Session failed, continuing..."

        log "Waiting $INTERVAL_SECONDS seconds until next session..."
        sleep "$INTERVAL_SECONDS"
    done
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo)
            TARGET_REPO="$2"
            shift 2
            ;;
        --interval)
            INTERVAL_SECONDS="$2"
            shift 2
            ;;
        --once)
            log "Running single session mode"
            if [ -n "$TARGET_REPO" ]; then
                log "Target repository: $TARGET_REPO"
            fi
            check_prerequisites
            run_claude_session
            exit $?
            ;;
        --help)
            echo "Usage: $0 [--repo OWNER/REPO] [--interval SECONDS] [--once] [--help]"
            echo "  --repo OWNER/REPO   Target repository (e.g., irek02/hello-world-docker)"
            echo "  --interval SECONDS  Set interval between runs (default: 300)"
            echo "  --once              Run once and exit"
            echo "  --help              Show this help"
            exit 0
            ;;
        *)
            log "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main
