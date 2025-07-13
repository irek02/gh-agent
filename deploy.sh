#!/bin/bash

# GitHub Agent EC2 Deployment Script
# Run this script to deploy the GitHub agent to EC2

set -e

echo "GitHub Agent EC2 Deployment"
echo "=========================="

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI not found. Please install AWS CLI first."
    echo "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check if AWS is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "ERROR: AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

# Default values
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.micro}"
KEY_NAME="${KEY_NAME:-github-agent-key}"
SECURITY_GROUP="${SECURITY_GROUP:-github-agent-sg}"

echo "Configuration:"
echo "  Instance Type: $INSTANCE_TYPE"
echo "  Key Pair: $KEY_NAME"
echo "  Security Group: $SECURITY_GROUP"
echo ""

# Get the latest Amazon Linux 2023 AMI
echo "Finding latest Amazon Linux 2023 AMI..."
AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text)

echo "Using AMI: $AMI_ID"

# Create security group if it doesn't exist
echo "Creating/checking security group..."
if ! aws ec2 describe-security-groups --group-names "$SECURITY_GROUP" &> /dev/null; then
    aws ec2 create-security-group \
        --group-name "$SECURITY_GROUP" \
        --description "Security group for GitHub Agent"
    
    # Allow SSH access
    aws ec2 authorize-security-group-ingress \
        --group-name "$SECURITY_GROUP" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0
    
    echo "Security group $SECURITY_GROUP created"
else
    echo "Security group $SECURITY_GROUP already exists"
fi

# Check if key pair exists
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" &> /dev/null; then
    echo "ERROR: Key pair '$KEY_NAME' not found."
    echo "Please create it first:"
    echo "  aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > $KEY_NAME.pem"
    echo "  chmod 400 $KEY_NAME.pem"
    exit 1
fi

# Read user data script
USER_DATA=$(base64 -i ec2-user-data.sh)

# Launch EC2 instance
echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --count 1 \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-groups "$SECURITY_GROUP" \
    --user-data "$USER_DATA" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=github-agent}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Instance launched: $INSTANCE_ID"

# Wait for instance to be running
echo "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo ""
echo "Next steps:"
echo "1. Wait 2-3 minutes for user data script to complete"
echo "2. Connect via SSH:"
echo "   ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP"
echo "3. Run setup script:"
echo "   sudo su - github-agent"
echo "   ./setup-tokens.sh"
echo ""
echo "To monitor deployment progress:"
echo "   ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP 'sudo tail -f /var/log/cloud-init-output.log'"