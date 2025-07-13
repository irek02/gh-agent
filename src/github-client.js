import { Octokit } from '@octokit/rest';

class GitHubClient {
  constructor(token, owner, repo) {
    this.octokit = new Octokit({ auth: token });
    this.owner = owner;
    this.repo = repo;
  }

  async getIssues() {
    try {
      const response = await this.octokit.rest.issues.listForRepo({
        owner: this.owner,
        repo: this.repo,
        state: 'open',
        sort: 'created',
        direction: 'desc'
      });
      return response.data.filter(issue => !issue.pull_request);
    } catch (error) {
      console.error('Error fetching issues:', error);
      throw error;
    }
  }

  async getPullRequests() {
    try {
      const response = await this.octokit.rest.pulls.list({
        owner: this.owner,
        repo: this.repo,
        state: 'open'
      });
      return response.data;
    } catch (error) {
      console.error('Error fetching pull requests:', error);
      throw error;
    }
  }

  async getPullRequestComments(pullNumber) {
    try {
      const [reviewComments, issueComments] = await Promise.all([
        this.octokit.rest.pulls.listReviewComments({
          owner: this.owner,
          repo: this.repo,
          pull_number: pullNumber
        }),
        this.octokit.rest.issues.listComments({
          owner: this.owner,
          repo: this.repo,
          issue_number: pullNumber
        })
      ]);
      
      return [...reviewComments.data, ...issueComments.data];
    } catch (error) {
      console.error('Error fetching PR comments:', error);
      throw error;
    }
  }

  async createPullRequest(title, body, head, base = 'main') {
    try {
      const response = await this.octokit.rest.pulls.create({
        owner: this.owner,
        repo: this.repo,
        title,
        body,
        head,
        base
      });
      return response.data;
    } catch (error) {
      console.error('Error creating pull request:', error);
      throw error;
    }
  }

  async createIssueComment(issueNumber, body) {
    try {
      const response = await this.octokit.rest.issues.createComment({
        owner: this.owner,
        repo: this.repo,
        issue_number: issueNumber,
        body
      });
      return response.data;
    } catch (error) {
      console.error('Error creating issue comment:', error);
      throw error;
    }
  }

  async getRepositoryInfo() {
    try {
      const response = await this.octokit.rest.repos.get({
        owner: this.owner,
        repo: this.repo
      });
      return response.data;
    } catch (error) {
      console.error('Error fetching repository info:', error);
      throw error;
    }
  }
}

export default GitHubClient;