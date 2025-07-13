# GitHub Agent - Automated Issue Processing with Claude AI

An intelligent GitHub automation system that monitors repositories for new issues and automatically creates pull requests to resolve them using Claude AI.

## Features

- **Automated Issue Processing**: Monitors GitHub repositories for new issues
- **AI-Powered Solutions**: Uses Claude AI to analyze issues and generate code solutions
- **Automatic Pull Requests**: Creates branches, commits changes, and opens pull requests
- **Comment Handling**: Processes PR comments and automatically addresses feedback
- **Persistent Tracking**: Tracks processed issues to avoid duplicates
- **Containerized Deployment**: Docker support for easy deployment

## How It Works

1. **Issue Detection**: Polls GitHub repository every X seconds for new issues
2. **AI Analysis**: Claude analyzes the issue and creates an implementation plan
3. **Code Generation**: Claude generates the necessary code changes
4. **Git Operations**: Creates a new branch, commits changes, and pushes to GitHub
5. **Pull Request**: Automatically creates a PR with the solution
6. **Comment Processing**: Monitors PR comments and addresses feedback automatically

## Setup

### Prerequisites

- Node.js 18+
- GitHub Personal Access Token with repo permissions
- Anthropic API key for Claude access
- Git configured with SSH or HTTPS access to your repository

### Installation

1. Clone this repository:
```bash
git clone <your-repo-url>
cd gh-agent
```

2. Install dependencies:
```bash
npm install
```

3. Create environment file:
```bash
cp .env.example .env
```

4. Configure your environment variables in `.env`:
```env
GITHUB_TOKEN=your_github_personal_access_token
ANTHROPIC_API_KEY=your_anthropic_api_key
GITHUB_OWNER=repository_owner
GITHUB_REPO=repository_name
POLL_INTERVAL_SECONDS=60
PROCESSED_ISSUES_FILE=./processed_issues.json
```

### Running Locally

```bash
npm start
```

The agent will start monitoring your repository and processing issues automatically.

## Docker Deployment

### Build and Run with Docker

```bash
# Build the image
docker build -t gh-agent .

# Run the container
docker run -d \
  --name github-agent \
  --env-file .env \
  -v $(pwd)/target-repo:/app/target-repo \
  -v $(pwd)/logs:/app/logs \
  -v $(pwd)/processed_issues.json:/app/processed_issues.json \
  gh-agent
```

### Using Docker Compose

```bash
docker-compose up -d
```

### AWS EC2 Deployment

1. Launch an EC2 instance with Docker installed
2. Copy your project files to the instance
3. Set up your `.env` file with the required credentials
4. Run with Docker Compose:

```bash
# On your EC2 instance
git clone <your-repo-url>
cd gh-agent
cp .env.example .env
# Edit .env with your credentials
docker-compose up -d
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GITHUB_TOKEN` | GitHub Personal Access Token | Required |
| `ANTHROPIC_API_KEY` | Anthropic API key for Claude | Required |
| `GITHUB_OWNER` | GitHub repository owner | Required |
| `GITHUB_REPO` | GitHub repository name | Required |
| `POLL_INTERVAL_SECONDS` | How often to check for new issues | 60 |
| `PROCESSED_ISSUES_FILE` | Path to store processed issue tracking | ./processed_issues.json |

### GitHub Token Permissions

Your GitHub token needs the following permissions:
- `repo` - Full control of private repositories
- `workflow` - Update GitHub Action workflows (if needed)

## Project Structure

```
gh-agent/
├── src/
│   ├── agent.js          # Main agent orchestration logic
│   ├── github-client.js  # GitHub API client
│   ├── claude-client.js  # Claude AI integration
│   ├── git-operations.js # Git operations (clone, branch, commit, push)
│   └── issue-tracker.js  # Issue and PR comment tracking
├── index.js              # Entry point and scheduler
├── Dockerfile            # Docker configuration
├── docker-compose.yml    # Docker Compose setup
└── README.md            # This file
```

## Usage Examples

### Creating a Test Issue

Create an issue in your target repository with a description like:

```
Add a new API endpoint for user profile retrieval

We need a new GET /api/users/:id/profile endpoint that returns user profile information. The endpoint should:

1. Accept a user ID parameter
2. Return user profile data in JSON format
3. Handle errors for non-existent users
4. Include proper authentication checks
```

The agent will:
1. Detect the new issue
2. Analyze it with Claude AI
3. Generate the necessary code
4. Create a branch like `issue-123-add-user-profile-endpoint`
5. Make commits with the implementation
6. Open a pull request with the solution

### Responding to PR Comments

When you comment on the generated PR with feedback like:

```
Please add input validation for the user ID parameter and include more detailed error messages.
```

The agent will:
1. Detect the new comment
2. Analyze the feedback with Claude
3. Update the code to address the comments
4. Commit the changes to the same branch

## Monitoring and Logs

- The agent logs all activities to the console
- Docker logs can be viewed with: `docker-compose logs -f gh-agent`
- Processed issues are tracked in `processed_issues.json`

## Security Considerations

- Keep your GitHub token and Anthropic API key secure
- Use environment variables, never commit credentials
- Consider running on a private network or VPC
- Monitor the agent's activities regularly
- Review generated code before merging PRs

## Limitations

- Currently supports one repository at a time
- Requires manual review of generated PRs before merging
- May need repository-specific fine-tuning for optimal results
- Large codebases may require additional context for Claude

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

ISC License - see LICENSE file for details

## YouTube Demo

This project was created for a YouTube demonstration of automated GitHub workflows using AI. The goal is to show how AI can be integrated into development workflows to automatically process issues and create pull requests.

## Support

For issues and questions, please create an issue in this repository.