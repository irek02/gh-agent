# EC2 Deployment Guide

This guide walks you through deploying the GitHub Agent to AWS EC2.

## Prerequisites

1. **AWS CLI installed and configured**
   ```bash
   aws configure
   ```

2. **Create EC2 Key Pair** (if you don't have one)
   ```bash
   aws ec2 create-key-pair --key-name github-agent-key --query 'KeyMaterial' --output text > github-agent-key.pem
   chmod 400 github-agent-key.pem
   ```

3. **GitHub Personal Access Token**
   - Go to https://github.com/settings/tokens
   - Create token with `repo` permissions
   - Save the token securely

4. **Anthropic API Key**
   - Go to https://console.anthropic.com/
   - Create API key
   - Save the key securely

## Deployment Steps

### 1. Deploy to EC2

```bash
# From the gh-agent directory
./deploy.sh
```

This will:
- Create security group (if needed)
- Launch EC2 instance
- Install all dependencies
- Set up the GitHub agent service

### 2. Connect to EC2

```bash
# Use the IP address from deployment output
ssh -i github-agent-key.pem ec2-user@YOUR_EC2_IP
```

### 3. Configure Authentication

```bash
# Switch to the github-agent user
sudo su - github-agent

# Run the setup script
./setup-tokens.sh
```

Follow the prompts to:
1. Set up GitHub CLI: `gh auth login`
2. Set up Claude CLI: `claude setup-token`
3. Edit environment file: `nano gh-agent/.env`

### 4. Start the Service

```bash
# Start the GitHub agent service
sudo systemctl start github-agent

# Check service status
sudo systemctl status github-agent

# View logs
sudo journalctl -u github-agent -f
```

## Service Management

### Check Service Status
```bash
sudo systemctl status github-agent
```

### View Logs
```bash
# Real-time logs
sudo journalctl -u github-agent -f

# Recent logs
sudo journalctl -u github-agent --since "1 hour ago"
```

### Restart Service
```bash
sudo systemctl restart github-agent
```

### Stop Service
```bash
sudo systemctl stop github-agent
```

## Configuration

### Environment Variables

Edit `/home/github-agent/gh-agent/.env`:

```bash
TARGET_REPO=your-username/your-repo
GITHUB_TOKEN=your_github_token
ANTHROPIC_API_KEY=your_anthropic_key
```

### Agent Settings

Modify `/home/github-agent/gh-agent/run-agent.sh` to change:
- Execution interval (default: 5 minutes)
- Target repository
- Logging settings

## Monitoring

### CloudWatch Logs (Optional)

Install CloudWatch agent to send logs to AWS:

```bash
sudo yum install -y amazon-cloudwatch-agent
```

### Local Monitoring

Monitor the agent execution:

```bash
# Watch the agent log file
tail -f /home/github-agent/gh-agent/agent.log

# Monitor system resources
htop
```

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure tokens are correctly set in `.env`
2. **Service Won't Start**: Check `sudo journalctl -u github-agent`
3. **No Issues Found**: Verify target repository in configuration
4. **Claude CLI Hanging**: Check API key and network connectivity

### Debug Mode

Enable debug logging by modifying the service:

```bash
sudo systemctl edit github-agent
```

Add:
```ini
[Service]
Environment="DEBUG=1"
```

### Manual Testing

Test the agent manually:

```bash
sudo su - github-agent
cd gh-agent
./run-agent.sh --once
```

## Security Considerations

1. **API Keys**: Store securely, rotate regularly
2. **Security Group**: Limit SSH access to your IP
3. **Updates**: Keep EC2 instance updated
4. **Monitoring**: Monitor for unusual activity

## Cost Optimization

1. **Instance Type**: Use t3.micro for basic workloads
2. **Spot Instances**: Consider for non-critical deployments
3. **Scheduling**: Add CloudWatch rules to stop/start automatically

## Cleanup

To remove the deployment:

```bash
# Get instance ID
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=github-agent" --query 'Reservations[0].Instances[0].InstanceId' --output text)

# Terminate instance
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

# Delete security group (after instance terminates)
aws ec2 delete-security-group --group-name github-agent-sg
```