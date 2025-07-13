import 'dotenv/config';
import cron from 'node-cron';
import GitHubAgent from './src/agent.js';

const config = {
  githubToken: process.env.GITHUB_TOKEN,
  anthropicApiKey: process.env.ANTHROPIC_API_KEY,
  owner: process.env.GITHUB_OWNER,
  repo: process.env.GITHUB_REPO,
  pollIntervalSeconds: parseInt(process.env.POLL_INTERVAL_SECONDS) || 60,
  processedIssuesFile: process.env.PROCESSED_ISSUES_FILE || './processed_issues.json'
};

function validateConfig() {
  const required = ['githubToken', 'anthropicApiKey', 'owner', 'repo'];
  const missing = required.filter(key => !config[key]);
  
  if (missing.length > 0) {
    console.error('Missing required environment variables:', missing);
    console.error('Please check your .env file');
    process.exit(1);
  }
}

async function main() {
  console.log('Starting GitHub Agent...');
  console.log(`Repository: ${config.owner}/${config.repo}`);
  console.log(`Poll interval: ${config.pollIntervalSeconds} seconds`);
  
  validateConfig();
  
  const agent = new GitHubAgent(config);
  
  try {
    await agent.initialize();
    console.log('Agent initialized successfully');
  } catch (error) {
    console.error('Failed to initialize agent:', error);
    process.exit(1);
  }

  const cronExpression = `*/${config.pollIntervalSeconds} * * * * *`;
  
  console.log(`Scheduling agent to run every ${config.pollIntervalSeconds} seconds`);
  
  cron.schedule(cronExpression, async () => {
    console.log(`\n--- Agent run at ${new Date().toISOString()} ---`);
    try {
      await agent.run();
      console.log('Agent run completed successfully');
    } catch (error) {
      console.error('Agent run failed:', error);
    }
  });

  console.log('Agent is running... Press Ctrl+C to stop');

  process.on('SIGINT', () => {
    console.log('\nReceived SIGINT, shutting down gracefully...');
    process.exit(0);
  });

  process.on('SIGTERM', () => {
    console.log('\nReceived SIGTERM, shutting down gracefully...');
    process.exit(0);
  });
}

main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});

export { GitHubAgent, config };