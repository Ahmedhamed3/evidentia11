#!/usr/bin/env node
/**
 * Forensic Tool Simulator CLI
 * 
 * Command-line interface for the forensic tool simulator.
 * Demonstrates how forensic tools can integrate with the Evidentia system.
 */

import { Command } from 'commander';
import inquirer from 'inquirer';
import chalk from 'chalk';
import ora from 'ora';
import { ForensicToolSimulator, SimulatorConfig } from './simulator';

const program = new Command();

// Default configuration
const defaultConfig: SimulatorConfig = {
  apiUrl: process.env.API_URL || 'http://localhost:3001',
  apiKey: process.env.API_KEY || 'demo-tool-key',
  toolName: process.env.TOOL_NAME || 'ForensicSimulator',
  toolVersion: process.env.TOOL_VERSION || '1.0.0',
};

program
  .name('forensic-sim')
  .description('Forensic Tool Simulator for Evidentia Chain-of-Custody System')
  .version('1.0.0');

program
  .command('analyze <evidenceId>')
  .description('Simulate a full forensic analysis of evidence')
  .option('-u, --api-url <url>', 'API URL', defaultConfig.apiUrl)
  .option('-k, --api-key <key>', 'API Key', defaultConfig.apiKey)
  .option('-t, --tool-name <name>', 'Tool name', defaultConfig.toolName)
  .action(async (evidenceId, options) => {
    const config: SimulatorConfig = {
      apiUrl: options.apiUrl,
      apiKey: options.apiKey,
      toolName: options.toolName,
      toolVersion: defaultConfig.toolVersion,
    };

    console.log(chalk.cyan('\n🔬 Forensic Tool Simulator'));
    console.log(chalk.gray(`Tool: ${config.toolName} v${config.toolVersion}`));
    console.log(chalk.gray(`API: ${config.apiUrl}\n`));

    const simulator = new ForensicToolSimulator(config);
    const spinner = ora('Starting analysis...').start();

    try {
      spinner.text = 'Fetching evidence details...';
      const evidence = await simulator.getEvidence(evidenceId);
      
      spinner.succeed(`Evidence found: ${evidence.metadata.name}`);
      console.log(chalk.gray(`  Case: ${evidence.caseId}`));
      console.log(chalk.gray(`  Status: ${evidence.status}`));
      console.log(chalk.gray(`  Custodian: ${evidence.currentCustodian}\n`));

      spinner.start('Running analysis...');
      const result = await simulator.simulateAnalysis(evidenceId);
      
      spinner.succeed('Analysis complete!');
      console.log(chalk.green('\n✅ Analysis Results:'));
      console.log(chalk.white(`  Findings: ${result.findings.substring(0, 100)}...`));
      console.log(chalk.white(`  Artifacts found: ${result.artifacts.length}`));
      console.log(chalk.white(`  Hashes verified: ${result.hashesVerified ? 'Yes' : 'No'}`));
      console.log(chalk.gray('\n  All actions have been logged to the blockchain.'));

    } catch (error: any) {
      spinner.fail(chalk.red(`Analysis failed: ${error.message}`));
      process.exit(1);
    }
  });

program
  .command('access <evidenceId>')
  .description('Log file access action')
  .option('-u, --api-url <url>', 'API URL', defaultConfig.apiUrl)
  .option('-k, --api-key <key>', 'API Key', defaultConfig.apiKey)
  .action(async (evidenceId, options) => {
    const config: SimulatorConfig = { ...defaultConfig, ...options };
    const simulator = new ForensicToolSimulator(config);
    const spinner = ora('Logging file access...').start();

    try {
      await simulator.simulateFileAccess(evidenceId);
      spinner.succeed('File access logged to blockchain');
    } catch (error: any) {
      spinner.fail(chalk.red(`Failed: ${error.message}`));
      process.exit(1);
    }
  });

program
  .command('extract <evidenceId>')
  .description('Simulate artifact extraction')
  .option('-u, --api-url <url>', 'API URL', defaultConfig.apiUrl)
  .option('-k, --api-key <key>', 'API Key', defaultConfig.apiKey)
  .option('-a, --artifacts <types>', 'Artifact types (comma-separated)', 'browser,email,document')
  .action(async (evidenceId, options) => {
    const config: SimulatorConfig = { ...defaultConfig, ...options };
    const simulator = new ForensicToolSimulator(config);
    const artifactTypes = options.artifacts.split(',');
    const spinner = ora('Extracting artifacts...').start();

    try {
      const artifacts = await simulator.simulateArtifactExtraction(evidenceId, artifactTypes);
      spinner.succeed(`Extracted ${artifacts.length} artifacts`);
      artifacts.forEach(a => console.log(chalk.gray(`  - ${a}`)));
    } catch (error: any) {
      spinner.fail(chalk.red(`Failed: ${error.message}`));
      process.exit(1);
    }
  });

program
  .command('info <evidenceId>')
  .description('Get evidence information')
  .option('-u, --api-url <url>', 'API URL', defaultConfig.apiUrl)
  .option('-k, --api-key <key>', 'API Key', defaultConfig.apiKey)
  .action(async (evidenceId, options) => {
    const config: SimulatorConfig = { ...defaultConfig, ...options };
    const simulator = new ForensicToolSimulator(config);
    const spinner = ora('Fetching evidence...').start();

    try {
      const evidence = await simulator.getEvidence(evidenceId);
      spinner.stop();
      
      console.log(chalk.cyan('\n📁 Evidence Information'));
      console.log(chalk.white(`  ID: ${evidence.id}`));
      console.log(chalk.white(`  Name: ${evidence.metadata.name}`));
      console.log(chalk.white(`  Case: ${evidence.caseId}`));
      console.log(chalk.white(`  Type: ${evidence.metadata.type}`));
      console.log(chalk.white(`  Status: ${evidence.status}`));
      console.log(chalk.white(`  Custodian: ${evidence.currentCustodian}`));
      console.log(chalk.white(`  Organization: ${evidence.currentOrg}`));
      console.log(chalk.gray(`  Hash: ${evidence.evidenceHash.substring(0, 32)}...`));
      console.log(chalk.gray(`  IPFS: ${evidence.ipfsHash}`));
      
    } catch (error: any) {
      spinner.fail(chalk.red(`Failed: ${error.message}`));
      process.exit(1);
    }
  });

program
  .command('interactive')
  .description('Start interactive mode')
  .action(async () => {
    console.log(chalk.cyan('\n🔬 Forensic Tool Simulator - Interactive Mode'));
    console.log(chalk.gray('Type "exit" to quit\n'));

    const { apiUrl, apiKey, toolName } = await inquirer.prompt([
      {
        type: 'input',
        name: 'apiUrl',
        message: 'API URL:',
        default: defaultConfig.apiUrl,
      },
      {
        type: 'input',
        name: 'apiKey',
        message: 'API Key:',
        default: defaultConfig.apiKey,
      },
      {
        type: 'input',
        name: 'toolName',
        message: 'Tool Name:',
        default: defaultConfig.toolName,
      },
    ]);

    const config: SimulatorConfig = {
      apiUrl,
      apiKey,
      toolName,
      toolVersion: defaultConfig.toolVersion,
    };

    const simulator = new ForensicToolSimulator(config);

    while (true) {
      const { action } = await inquirer.prompt([
        {
          type: 'list',
          name: 'action',
          message: 'Select action:',
          choices: [
            { name: '📁 Get evidence info', value: 'info' },
            { name: '🔬 Run full analysis', value: 'analyze' },
            { name: '📂 Log file access', value: 'access' },
            { name: '🔍 Extract artifacts', value: 'extract' },
            { name: '🚪 Exit', value: 'exit' },
          ],
        },
      ]);

      if (action === 'exit') {
        console.log(chalk.gray('Goodbye!'));
        break;
      }

      const { evidenceId } = await inquirer.prompt([
        {
          type: 'input',
          name: 'evidenceId',
          message: 'Evidence ID:',
        },
      ]);

      const spinner = ora('Processing...').start();

      try {
        switch (action) {
          case 'info':
            const evidence = await simulator.getEvidence(evidenceId);
            spinner.stop();
            console.log(chalk.cyan('\nEvidence:'), JSON.stringify(evidence, null, 2));
            break;
          case 'analyze':
            const result = await simulator.simulateAnalysis(evidenceId);
            spinner.succeed('Analysis complete');
            console.log(chalk.green('\nResults:'), JSON.stringify(result, null, 2));
            break;
          case 'access':
            await simulator.simulateFileAccess(evidenceId);
            spinner.succeed('File access logged');
            break;
          case 'extract':
            const artifacts = await simulator.simulateArtifactExtraction(evidenceId, ['browser', 'email', 'document']);
            spinner.succeed(`Extracted ${artifacts.length} artifacts`);
            break;
        }
      } catch (error: any) {
        spinner.fail(chalk.red(error.message));
      }

      console.log('');
    }
  });

program.parse();

