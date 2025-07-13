import GitHubClient from './github-client.js';
import ClaudeClient from './claude-client.js';
import GitOperations from './git-operations.js';
import IssueTracker from './issue-tracker.js';

class GitHubAgent {
  constructor(config) {
    this.github = new GitHubClient(config.githubToken, config.owner, config.repo);
    this.claude = new ClaudeClient(config.anthropicApiKey);
    this.git = new GitOperations('./target-repo');
    this.tracker = new IssueTracker(config.processedIssuesFile);
    this.config = config;
  }

  async initialize() {
    await this.tracker.load();
    const repoUrl = `https://github.com/${this.config.owner}/${this.config.repo}.git`;
    await this.git.ensureRepository(repoUrl);
    console.log('Agent initialized successfully');
  }

  async processNewIssues() {
    try {
      console.log('Checking for new issues...');
      const issues = await this.github.getIssues();
      const newIssues = this.tracker.getNewIssues(issues);

      if (newIssues.length === 0) {
        console.log('No new issues found');
        return;
      }

      console.log(`Found ${newIssues.length} new issue(s)`);

      for (const issue of newIssues) {
        await this.processIssue(issue);
        this.tracker.markIssueAsProcessed(issue.number);
        await this.tracker.save();
      }
    } catch (error) {
      console.error('Error processing new issues:', error);
    }
  }

  async processIssue(issue) {
    try {
      console.log(`Processing issue #${issue.number}: ${issue.title}`);

      const repoInfo = await this.github.getRepositoryInfo();
      const repositoryContext = `Repository: ${repoInfo.full_name}\nDescription: ${repoInfo.description}\nLanguage: ${repoInfo.language}`;

      const plan = await this.claude.analyzeIssue(issue, repositoryContext);
      console.log('Issue analysis completed:', plan.analysis);

      await this.git.resetToMain();
      await this.git.createBranch(plan.branch_name);

      for (let i = 0; i < plan.files_to_modify.length; i++) {
        const filePath = plan.files_to_modify[i];
        await this.modifyFile(issue, plan, filePath, i);
      }

      await this.git.pushBranch(plan.branch_name);

      const prTitle = `Fix #${issue.number}: ${issue.title}`;
      const prBody = `Fixes #${issue.number}\n\n${plan.analysis}\n\n## Implementation\n${plan.implementation_plan.map((step, i) => `${i + 1}. ${step}`).join('\n')}`;

      const pr = await this.github.createPullRequest(prTitle, prBody, plan.branch_name);
      console.log(`Created pull request: ${pr.html_url}`);

    } catch (error) {
      console.error(`Error processing issue #${issue.number}:`, error);
    }
  }

  async modifyFile(issue, plan, filePath, stepIndex) {
    try {
      let fileContent = '';
      const fileExists = await this.git.fileExists(filePath);
      
      if (fileExists) {
        fileContent = await this.git.readFile(filePath);
      }

      const modifiedContent = await this.claude.generateCodeChanges(issue, plan, fileContent, filePath);
      await this.git.writeFile(filePath, modifiedContent);

      const commitMessage = plan.commit_messages[stepIndex] || `Update ${filePath} for issue #${issue.number}`;
      await this.git.commitChanges(commitMessage, [filePath]);

    } catch (error) {
      console.error(`Error modifying file ${filePath}:`, error);
      throw error;
    }
  }

  async processPullRequestComments() {
    try {
      console.log('Checking for PR comments...');
      const pullRequests = await this.github.getPullRequests();

      for (const pr of pullRequests) {
        if (!pr.head.ref.startsWith('issue-')) continue;

        const comments = await this.github.getPullRequestComments(pr.number);
        const unprocessedComments = this.tracker.getUnprocessedComments(comments, pr.number);

        if (unprocessedComments.length === 0) continue;

        console.log(`Found ${unprocessedComments.length} new comment(s) on PR #${pr.number}`);
        await this.processPRComments(pr, unprocessedComments);

        const latestComment = comments.reduce((latest, comment) => 
          new Date(comment.created_at) > new Date(latest.created_at) ? comment : latest
        );
        this.tracker.updatePRCommentTimestamp(pr.number, latestComment.created_at);
        await this.tracker.save();
      }
    } catch (error) {
      console.error('Error processing PR comments:', error);
    }
  }

  async processPRComments(pullRequest, comments) {
    try {
      const repoInfo = await this.github.getRepositoryInfo();
      const repositoryContext = `Repository: ${repoInfo.full_name}\nDescription: ${repoInfo.description}\nLanguage: ${repoInfo.language}`;

      const analysis = await this.claude.analyzeComments(comments, pullRequest, repositoryContext);
      console.log('Comment analysis completed:', analysis.analysis);

      await this.git.switchToBranch(pullRequest.head.ref);

      for (let i = 0; i < analysis.files_to_modify.length; i++) {
        const filePath = analysis.files_to_modify[i];
        await this.modifyFileForComments(pullRequest, analysis, filePath, i);
      }

      await this.git.pushBranch(pullRequest.head.ref);
      console.log(`Updated PR #${pullRequest.number} based on comments`);

    } catch (error) {
      console.error(`Error processing comments for PR #${pullRequest.number}:`, error);
    }
  }

  async modifyFileForComments(pullRequest, analysis, filePath, stepIndex) {
    try {
      const fileContent = await this.git.readFile(filePath);
      const modifiedContent = await this.claude.generateCodeChanges(
        { title: pullRequest.title, body: `Addressing comments: ${analysis.analysis}`, number: pullRequest.number },
        analysis,
        fileContent,
        filePath
      );

      await this.git.writeFile(filePath, modifiedContent);

      const commitMessage = analysis.commit_messages[stepIndex] || `Address comments for ${filePath}`;
      await this.git.commitChanges(commitMessage, [filePath]);

    } catch (error) {
      console.error(`Error modifying file ${filePath} for comments:`, error);
      throw error;
    }
  }

  async run() {
    try {
      await this.processPullRequestComments();
      await this.processNewIssues();
    } catch (error) {
      console.error('Error in agent run:', error);
    }
  }
}

export default GitHubAgent;