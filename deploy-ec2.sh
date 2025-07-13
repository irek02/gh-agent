#!/bin/bash

# GitHub Agent EC2 Deployment Script
set -e

# Configuration
INSTANCE_TYPE="t3.micro"
AMI_ID="ami-0c02fb55956c7d316"  # Amazon Linux 2023 AMI (update as needed)
KEY_NAME="github-agent-key"
SECURITY_GROUP_NAME="github-agent-sg"
INSTANCE_NAME="github-agent"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    echo_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo_error "AWS credentials not configured. Run 'aws configure' first."
    exit 1
fi

echo_info "Starting EC2 deployment for GitHub Agent..."

# Get default VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
if [ "$VPC_ID" = "None" ]; then
    echo_error "No default VPC found. Please create one or specify a VPC ID."
    exit 1
fi
echo_info "Using VPC: $VPC_ID"

# Create security group if it doesn't exist
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)

if [ "$SECURITY_GROUP_ID" = "None" ] || [ -z "$SECURITY_GROUP_ID" ]; then
    echo_info "Creating security group: $SECURITY_GROUP_NAME"
    SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --group-name "$SECURITY_GROUP_NAME" \
        --description "Security group for GitHub Agent" \
        --vpc-id "$VPC_ID" \
        --query 'GroupId' \
        --output text)
    
    # Add SSH access
    aws ec2 authorize-security-group-ingress \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0
else
    echo_info "Using existing security group: $SECURITY_GROUP_ID"
fi

# Create key pair if it doesn't exist
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" &> /dev/null; then
    echo_info "Creating key pair: $KEY_NAME"
    aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "${KEY_NAME}.pem"
    chmod 400 "${KEY_NAME}.pem"
    echo_info "Key pair saved to ${KEY_NAME}.pem"
else
    echo_info "Using existing key pair: $KEY_NAME"
fi

# Create user data script for EC2 instance
cat > user-data.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y docker git

# Start Docker service
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create app directory
mkdir -p /home/ec2-user/github-agent
cd /home/ec2-user/github-agent

# Clone the repository (will be updated by user)
# Note: User needs to set up GitHub credentials and clone their repo

# Create a startup script
cat > /home/ec2-user/start-agent.sh << 'SCRIPT'
#!/bin/bash
cd /home/ec2-user/github-agent

# Pull latest changes
git pull origin main

# Build and run the container
docker-compose down
docker-compose build
docker-compose up -d

echo "GitHub Agent started successfully!"
docker-compose logs -f
SCRIPT

chmod +x /home/ec2-user/start-agent.sh
chown -R ec2-user:ec2-user /home/ec2-user/github-agent
chown ec2-user:ec2-user /home/ec2-user/start-agent.sh

# Create systemd service for auto-start
cat > /etc/systemd/system/github-agent.service << 'SERVICE'
[Unit]
Description=GitHub Agent
After=docker.service
Requires=docker.service

[Service]
Type=forking
User=ec2-user
WorkingDirectory=/home/ec2-user/github-agent
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0
Restart=on-failure
StartLimitIntervalSec=60s
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
SERVICE

systemctl enable github-agent.service
EOF

# Launch EC2 instance
echo_info "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --count 1 \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --user-data file://user-data.sh \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --query 'Instances[0].InstanceId' \
    --output text)

echo_info "Instance launched with ID: $INSTANCE_ID"

# Wait for instance to be running
echo_info "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo_info "Instance is running!"
echo_info "Public IP: $PUBLIC_IP"
echo_info "SSH command: ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP"

# Create deployment instructions
cat > DEPLOYMENT_INSTRUCTIONS.md << EOF
# GitHub Agent Deployment Instructions

## EC2 Instance Details
- Instance ID: $INSTANCE_ID
- Public IP: $PUBLIC_IP
- SSH Key: ${KEY_NAME}.pem

## SSH Access
\`\`\`bash
ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP
\`\`\`

## Setup Steps on EC2

1. **Clone your repository:**
   \`\`\`bash
   cd /home/ec2-user/github-agent
   git clone https://github.com/YOUR_USERNAME/gh-agent.git .
   \`\`\`

2. **Set up environment variables:**
   \`\`\`bash
   cp .env.example .env
   nano .env  # Edit with your API keys and settings
   \`\`\`

3. **Start the agent:**
   \`\`\`bash
   ./start-agent.sh
   \`\`\`

4. **Enable auto-start (optional):**
   \`\`\`bash
   sudo systemctl start github-agent
   sudo systemctl enable github-agent
   \`\`\`

## Environment Variables Required
- ANTHROPIC_API_KEY: Your Anthropic API key
- GITHUB_TOKEN: GitHub personal access token with repo permissions
- TARGET_REPO: Repository to monitor (format: owner/repo)
- GIT_USER_NAME: Name for git commits
- GIT_USER_EMAIL: Email for git commits

## Monitoring
- View logs: \`docker-compose logs -f\`
- Check status: \`docker-compose ps\`
- Restart: \`docker-compose restart\`

## Cleanup
To terminate the instance:
\`\`\`bash
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
\`\`\`
EOF

echo_info "Deployment instructions saved to DEPLOYMENT_INSTRUCTIONS.md"
echo_info "Deployment completed successfully!"

# Cleanup temporary files
rm -f user-data.sh