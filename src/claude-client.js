import Anthropic from '@anthropic-ai/sdk';

class ClaudeClient {
  constructor(apiKey) {
    this.anthropic = new Anthropic({ apiKey });
  }

  async analyzeIssue(issue, repositoryContext = '') {
    const prompt = `You are a software engineer working on a GitHub repository. You need to analyze this issue and provide a solution.

Repository Context:
${repositoryContext}

Issue Title: ${issue.title}
Issue Description: ${issue.body}
Issue Number: #${issue.number}

Please provide:
1. A brief analysis of what needs to be done
2. The files that likely need to be modified
3. A step-by-step implementation plan
4. Suggested commit messages for each logical change

Respond in JSON format:
{
  "analysis": "Brief analysis of the issue",
  "files_to_modify": ["path/to/file1.js", "path/to/file2.js"],
  "implementation_plan": [
    "Step 1: Description",
    "Step 2: Description"
  ],
  "commit_messages": [
    "feat: add new feature X",
    "fix: resolve issue with Y"
  ],
  "branch_name": "issue-${issue.number}-brief-description"
}`;

    try {
      const response = await this.anthropic.messages.create({
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 2000,
        messages: [{
          role: 'user',
          content: prompt
        }]
      });

      return JSON.parse(response.content[0].text);
    } catch (error) {
      console.error('Error analyzing issue with Claude:', error);
      throw error;
    }
  }

  async generateCodeChanges(issue, plan, fileContent, filePath) {
    const prompt = `You are implementing changes for GitHub issue #${issue.number}.

Issue: ${issue.title}
Description: ${issue.body}

Implementation Plan: ${plan.analysis}

Current file path: ${filePath}
Current file content:
\`\`\`
${fileContent}
\`\`\`

Please provide the modified file content that implements the required changes. Return only the complete modified file content, no explanations or markdown formatting.`;

    try {
      const response = await this.anthropic.messages.create({
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 4000,
        messages: [{
          role: 'user',
          content: prompt
        }]
      });

      return response.content[0].text;
    } catch (error) {
      console.error('Error generating code changes:', error);
      throw error;
    }
  }

  async analyzeComments(comments, pullRequest, repositoryContext = '') {
    const commentsText = comments.map(c => `${c.user.login}: ${c.body}`).join('\n\n');
    
    const prompt = `You are reviewing comments on a pull request and need to address them.

Repository Context:
${repositoryContext}

Pull Request: ${pullRequest.title}
PR Description: ${pullRequest.body}

Comments to address:
${commentsText}

Please provide:
1. Analysis of what needs to be changed based on the comments
2. Files that need to be modified
3. Implementation plan to address the feedback

Respond in JSON format:
{
  "analysis": "What needs to be changed based on comments",
  "files_to_modify": ["path/to/file1.js"],
  "implementation_plan": [
    "Step 1: Address comment about X",
    "Step 2: Fix issue Y mentioned in review"
  ],
  "commit_messages": [
    "fix: address review feedback on X",
    "refactor: improve Y based on comments"
  ]
}`;

    try {
      const response = await this.anthropic.messages.create({
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 2000,
        messages: [{
          role: 'user',
          content: prompt
        }]
      });

      return JSON.parse(response.content[0].text);
    } catch (error) {
      console.error('Error analyzing comments with Claude:', error);
      throw error;
    }
  }
}

export default ClaudeClient;