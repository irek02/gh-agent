#!/bin/bash

# EC2 User Data Script for GitHub Agent
# This script runs when the EC2 instance first boots up

set -e

# Update system
yum update -y

# Install required packages
yum install -y git curl wget unzip jq

# Install Node.js (for npm)
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
yum install -y nodejs

# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/rpm/gh-cli.repo | tee /etc/yum.repos.d/gh-cli.repo
yum install -y gh

# Create github-agent user
useradd -m -s /bin/bash github-agent
mkdir -p /home/github-agent/.ssh
chown github-agent:github-agent /home/github-agent/.ssh

# Install Claude CLI
sudo -u github-agent bash -c '
cd /home/github-agent
curl -fsSL https://api.claude.ai/cli/install.sh | bash
echo "export PATH=\"$HOME/.local/bin:$PATH\"" >> ~/.bashrc
'

# Clone the repository
sudo -u github-agent bash -c '
cd /home/github-agent
git clone https://github.com/irek02/gh-agent.git
cd gh-agent
'

# Set up environment
cat > /home/github-agent/gh-agent/.env << 'EOF'
# GitHub Agent Environment Variables
TARGET_REPO=irek02/hello-world-docker
GITHUB_TOKEN=
ANTHROPIC_API_KEY=
EOF

chown github-agent:github-agent /home/github-agent/gh-agent/.env

# Create systemd service
cat > /etc/systemd/system/github-agent.service << 'EOF'
[Unit]
Description=GitHub Agent
After=network.target

[Service]
Type=simple
User=github-agent
WorkingDirectory=/home/github-agent/gh-agent
Environment=PATH=/home/github-agent/.local/bin:/usr/local/bin:/usr/bin:/bin
EnvironmentFile=/home/github-agent/gh-agent/.env
ExecStart=/home/github-agent/gh-agent/run-agent.sh
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable but don't start the service yet (need to configure tokens first)
systemctl enable github-agent

# Create setup completion script
cat > /home/github-agent/setup-tokens.sh << 'EOF'
#!/bin/bash

echo "GitHub Agent EC2 Setup"
echo "======================"
echo ""
echo "Please set up your authentication tokens:"
echo ""
echo "1. Set up GitHub CLI authentication:"
echo "   gh auth login"
echo ""
echo "2. Set up Claude CLI authentication:"
echo "   claude setup-token"
echo ""
echo "3. Edit the .env file to add your tokens:"
echo "   nano /home/github-agent/gh-agent/.env"
echo ""
echo "4. Start the service:"
echo "   sudo systemctl start github-agent"
echo ""
echo "5. Check service status:"
echo "   sudo systemctl status github-agent"
echo ""
echo "6. View logs:"
echo "   sudo journalctl -u github-agent -f"
EOF

chmod +x /home/github-agent/setup-tokens.sh
chown github-agent:github-agent /home/github-agent/setup-tokens.sh

echo "EC2 instance setup complete. Connect via SSH and run: /home/github-agent/setup-tokens.sh"