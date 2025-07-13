import fs from 'fs/promises';
import path from 'path';

class IssueTracker {
  constructor(dataFilePath = './processed_issues.json') {
    this.dataFilePath = dataFilePath;
    this.processedIssues = new Set();
    this.processedPRs = new Map(); // PR number -> last comment timestamp
  }

  async load() {
    try {
      const data = await fs.readFile(this.dataFilePath, 'utf8');
      const parsed = JSON.parse(data);
      this.processedIssues = new Set(parsed.processedIssues || []);
      this.processedPRs = new Map(parsed.processedPRs || []);
    } catch (error) {
      if (error.code !== 'ENOENT') {
        console.error('Error loading processed issues:', error);
      }
    }
  }

  async save() {
    try {
      const data = {
        processedIssues: Array.from(this.processedIssues),
        processedPRs: Array.from(this.processedPRs.entries())
      };
      await fs.writeFile(this.dataFilePath, JSON.stringify(data, null, 2));
    } catch (error) {
      console.error('Error saving processed issues:', error);
    }
  }

  isIssueProcessed(issueNumber) {
    return this.processedIssues.has(issueNumber);
  }

  markIssueAsProcessed(issueNumber) {
    this.processedIssues.add(issueNumber);
  }

  getNewIssues(issues) {
    return issues.filter(issue => !this.isIssueProcessed(issue.number));
  }

  shouldProcessPRComments(pullNumber, latestCommentDate) {
    const lastProcessed = this.processedPRs.get(pullNumber);
    if (!lastProcessed) {
      return true;
    }
    return new Date(latestCommentDate) > new Date(lastProcessed);
  }

  updatePRCommentTimestamp(pullNumber, timestamp) {
    this.processedPRs.set(pullNumber, timestamp);
  }

  getUnprocessedComments(comments, pullNumber) {
    const lastProcessed = this.processedPRs.get(pullNumber);
    if (!lastProcessed) {
      return comments;
    }
    
    return comments.filter(comment => 
      new Date(comment.created_at) > new Date(lastProcessed)
    );
  }
}

export default IssueTracker;