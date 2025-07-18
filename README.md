# GitHub Agent

Automated GitHub repository agent using Claude CLI that monitors repositories for issues and pull requests, then takes action to resolve them.

## Features

- Monitors GitHub repositories for open issues and pull requests
- Automatically responds to PR comments and implements requested changes
- Creates fixes for actionable issues
- Runs health checks and maintenance tasks
- Dockerized for easy deployment
- AWS EC2 deployment support

## Quick Start

### Local Testing

1. **Setup environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your API keys and target repository
   ```

2. **Test locally:**
   ```bash
   ./test-local.sh
   ```

3. **Run continuously:**
   ```bash
   docker-compose up -d
   ```

### AWS EC2 Deployment

#### Option 1: Manual EC2 Setup (Recommended)

1. **Create EC2 Infrastructure:**
   ```bash
   # Get default VPC
   VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
   
   # Create security group
   SECURITY_GROUP_ID=$(aws ec2 create-security-group \
       --group-name "github-agent-sg" \
       --description "Security group for GitHub Agent" \
       --vpc-id "$VPC_ID" \
       --query 'GroupId' --output text)
   
   # Add SSH access
   aws ec2 authorize-security-group-ingress \
       --group-id "$SECURITY_GROUP_ID" \
       --protocol tcp --port 22 --cidr 0.0.0.0/0
   
   # Create key pair
   aws ec2 create-key-pair --key-name "github-agent-key" \
       --query 'KeyMaterial' --output text > github-agent-key.pem
   chmod 400 github-agent-key.pem
   ```

2. **Launch EC2 Instance:**
   ```bash
   # Launch simple instance
   INSTANCE_ID=$(aws ec2 run-instances \
       --image-id ami-0c02fb55956c7d316 \
       --count 1 \
       --instance-type t3.micro \
       --key-name github-agent-key \
       --security-group-ids "$SECURITY_GROUP_ID" \
       --query 'Instances[0].InstanceId' --output text)
   
   # Wait for instance to start
   aws ec2 wait instance-running --instance-ids $INSTANCE_ID
   
   # Get public IP
   PUBLIC_IP=$(aws ec2 describe-instances \
       --instance-ids $INSTANCE_ID \
       --query 'Reservations[0].Instances[0].PublicIpAddress' \
       --output text)
   
   echo "SSH: ssh -i github-agent-key.pem ec2-user@$PUBLIC_IP"
   ```

3. **Setup on EC2:**
   ```bash
   # SSH into instance
   ssh -i github-agent-key.pem ec2-user@$PUBLIC_IP
   
   # Install Docker and Git
   sudo yum update -y
   sudo yum install -y docker git
   sudo systemctl start docker
   sudo systemctl enable docker
   sudo usermod -a -G docker ec2-user
   
   # Re-login to apply docker group (or logout/login)
   exit
   ssh -i github-agent-key.pem ec2-user@$PUBLIC_IP
   
   # Clone repository
   git clone https://github.com/YOUR_USERNAME/gh-agent.git
   cd gh-agent
   
   # Create environment file
   cp .env.example .env
   # Edit .env with your API keys and target repository
   nano .env
   
   # Build and test
   docker build -t github-agent .
   ./run-local-test.sh
   ```

4. **Run Continuously:**
   ```bash
   # Option A: Docker Compose (runs every 10 minutes)
   docker-compose up -d
   
   # Option B: Manual execution
   docker run --rm \
       -e ANTHROPIC_API_KEY="your-key" \
       -e GITHUB_TOKEN="your-token" \
       -e TARGET_REPO="owner/repo" \
       -v github-agent-workspace:/workspace \
       github-agent
   ```

#### Option 2: Automated Script

1. **Use the deployment script:**
   ```bash
   ./deploy-ec2.sh
   ```

2. **Follow the generated instructions in `DEPLOYMENT_INSTRUCTIONS.md`**

## Configuration

### Required Environment Variables

- `ANTHROPIC_API_KEY`: Your Anthropic API key for Claude CLI
- `GITHUB_TOKEN`: GitHub personal access token with repo permissions
- `TARGET_REPO`: Repository to monitor (format: `owner/repo`)

### Optional Environment Variables

- `GIT_USER_NAME`: Name for git commits (default: "GitHub Agent")
- `GIT_USER_EMAIL`: Email for git commits (default: "agent@github.com")

## How It Works

1. **Pull Request Monitoring**: Checks for unaddressed comments and implements requested changes
2. **Issue Processing**: Identifies actionable issues and creates fix PRs
3. **Repository Health**: Runs lints, tests, and security checks
4. **Automation**: Executes every 10 minutes while respecting rate limits

## Safety Features

- Never force pushes to main branches
- Creates feature branches for all changes
- Adds labels to track bot activity
- Respects GitHub API rate limits
- Human review required before merging

## Project Structure

```
.
   Dockerfile              # Container definition
   docker-compose.yml      # Local orchestration
   CLAUDE_INSTRUCTIONS.md   # Agent instructions
   deploy-ec2.sh           # AWS deployment script
   test-local.sh           # Local testing script
   .env.example            # Environment template
   README.md               # This file
```

## Troubleshooting

### EC2 Deployment Issues

**Problem: Can't SSH to instance**
- Ensure security group allows SSH (port 22) from your IP
- Verify key pair exists and has correct permissions (`chmod 400 key.pem`)
- Check instance is in "running" state

**Problem: Docker permission denied**
- After adding user to docker group, you must re-login:
  ```bash
  exit
  ssh -i key.pem ec2-user@$PUBLIC_IP
  ```

**Problem: Agent execution fails**
- Verify all environment variables are set correctly
- Check Docker container logs: `docker logs <container-id>`
- Ensure GitHub token has repo permissions
- Test Claude CLI manually: `claude --version`

**Problem: Bot processes same issue repeatedly**
- Check if `bot-handled` label exists in repository
- Create the label: `gh label create "bot-handled" --description "Issue processed by bot" --color "0075ca"`
- Verify label management in agent output

### Docker Issues

**Problem: Image build fails**
- Check network connectivity for package downloads
- Verify Dockerfile syntax
- Try building with `--no-cache` flag

**Problem: Container exits immediately**
- Check environment variables are properly set
- Review container logs for error messages
- Test individual tools: `docker run --rm github-agent claude --version`

### GitHub API Issues

**Problem: Rate limiting**
- Agent respects GitHub API limits automatically
- For heavy usage, consider GitHub Enterprise or multiple tokens

**Problem: Permission errors**
- Ensure GitHub token has required scopes:
  - `repo` (full repository access)
  - `read:user` (read user profile)
- Test token: `gh auth status`

## Monitoring

### View Agent Activity

```bash
# Check running containers
docker ps

# View logs (if container not using --rm)
docker logs <container-id>

# Monitor with Docker Compose
docker-compose logs -f

# Check workspace volume
docker run --rm -v github-agent-workspace:/workspace alpine ls -la /workspace/
```

### GitHub Repository Monitoring

The agent adds labels to track its activity:
- `bot-working`: Currently processing issue
- `bot-handled`: Issue completed by bot  
- `bot-skipped`: Issue skipped (not actionable)

## Contributing

This agent is designed to work with any GitHub repository. Customize the `CLAUDE_INSTRUCTIONS.md` file to modify behavior for your specific needs.

### Tested Configurations

- ✅ **AWS EC2** (Amazon Linux 2023, t3.micro)
- ✅ **Local Docker** (macOS, Ubuntu)
- ✅ **GitHub.com repositories**
- ✅ **Claude CLI 1.0.51**
- ✅ **GitHub CLI 2.63.0**