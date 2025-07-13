import simpleGit from 'simple-git';
import fs from 'fs/promises';
import path from 'path';

class GitOperations {
  constructor(repoPath = './target-repo') {
    this.repoPath = repoPath;
    this.git = null; // Initialize later
  }

  async cloneRepository(repoUrl) {
    try {
      console.log(`Cloning repository: ${repoUrl}`);
      await simpleGit().clone(repoUrl, this.repoPath);
      this.git = simpleGit(this.repoPath);
      console.log('Repository cloned successfully');
    } catch (error) {
      console.error('Error cloning repository:', error);
      throw error;
    }
  }

  async ensureRepository(repoUrl) {
    try {
      await fs.access(this.repoPath);
      this.git = simpleGit(this.repoPath);
      await this.git.fetch();
      await this.git.pull();
      console.log('Repository updated');
    } catch (error) {
      console.log('Repository not found locally, cloning...');
      await this.cloneRepository(repoUrl);
    }
  }

  async createBranch(branchName) {
    try {
      await this.git.checkoutLocalBranch(branchName);
      console.log(`Created and switched to branch: ${branchName}`);
    } catch (error) {
      console.error('Error creating branch:', error);
      throw error;
    }
  }

  async switchToBranch(branchName) {
    try {
      await this.git.checkout(branchName);
      console.log(`Switched to branch: ${branchName}`);
    } catch (error) {
      console.error('Error switching branch:', error);
      throw error;
    }
  }

  async commitChanges(message, files = []) {
    try {
      if (files.length > 0) {
        await this.git.add(files);
      } else {
        await this.git.add('.');
      }
      
      await this.git.commit(message);
      console.log(`Committed changes: ${message}`);
    } catch (error) {
      console.error('Error committing changes:', error);
      throw error;
    }
  }

  async pushBranch(branchName) {
    try {
      await this.git.push('origin', branchName);
      console.log(`Pushed branch: ${branchName}`);
    } catch (error) {
      console.error('Error pushing branch:', error);
      throw error;
    }
  }

  async readFile(filePath) {
    try {
      const fullPath = path.join(this.repoPath, filePath);
      return await fs.readFile(fullPath, 'utf8');
    } catch (error) {
      console.error(`Error reading file ${filePath}:`, error);
      throw error;
    }
  }

  async writeFile(filePath, content) {
    try {
      const fullPath = path.join(this.repoPath, filePath);
      const dir = path.dirname(fullPath);
      await fs.mkdir(dir, { recursive: true });
      await fs.writeFile(fullPath, content, 'utf8');
      console.log(`File written: ${filePath}`);
    } catch (error) {
      console.error(`Error writing file ${filePath}:`, error);
      throw error;
    }
  }

  async fileExists(filePath) {
    try {
      const fullPath = path.join(this.repoPath, filePath);
      await fs.access(fullPath);
      return true;
    } catch {
      return false;
    }
  }

  async getStatus() {
    try {
      return await this.git.status();
    } catch (error) {
      console.error('Error getting git status:', error);
      throw error;
    }
  }

  async resetToMain() {
    try {
      await this.git.checkout('main');
      await this.git.pull();
      console.log('Reset to main branch');
    } catch (error) {
      console.error('Error resetting to main:', error);
      throw error;
    }
  }

  async listFiles(directory = '.') {
    try {
      const fullPath = path.join(this.repoPath, directory);
      const files = await fs.readdir(fullPath, { withFileTypes: true });
      return files.map(file => ({
        name: file.name,
        isDirectory: file.isDirectory(),
        path: path.join(directory, file.name)
      }));
    } catch (error) {
      console.error(`Error listing files in ${directory}:`, error);
      throw error;
    }
  }
}

export default GitOperations;