/**
 * Forensic Tool Simulator Demo Script
 * 
 * Runs a complete demonstration of forensic tool integration
 * with the Evidentia Chain-of-Custody system.
 */

import chalk from 'chalk';
import { ForensicToolSimulator, SimulatorConfig } from './simulator';

const config: SimulatorConfig = {
  apiUrl: process.env.API_URL || 'http://localhost:3001',
  apiKey: process.env.API_KEY || 'demo-tool-key',
  toolName: 'AutopsySimulator',
  toolVersion: '4.21.0',
};

async function runDemo() {
  console.log(chalk.cyan.bold('\n╔══════════════════════════════════════════════════════════════╗'));
  console.log(chalk.cyan.bold('║     Evidentia Forensic Tool Integration Demo                  ║'));
  console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════════════╝\n'));

  console.log(chalk.gray('This demo simulates how a forensic tool like Autopsy'));
  console.log(chalk.gray('integrates with the blockchain-based Chain-of-Custody system.\n'));

  console.log(chalk.yellow('Configuration:'));
  console.log(chalk.white(`  Tool: ${config.toolName} v${config.toolVersion}`));
  console.log(chalk.white(`  API: ${config.apiUrl}`));
  console.log(chalk.white(`  API Key: ${config.apiKey.substring(0, 10)}...`));
  console.log('');

  // Note: This demo requires evidence to already exist in the system
  // In a real scenario, you would use an actual evidence ID
  const evidenceId = process.argv[2] || 'EVD-DEMO001';

  console.log(chalk.yellow(`Target Evidence: ${evidenceId}\n`));

  const simulator = new ForensicToolSimulator(config);

  try {
    // Step 1: Get evidence info
    console.log(chalk.cyan('Step 1: Retrieving evidence information...'));
    console.log(chalk.gray('─'.repeat(50)));
    
    const evidence = await simulator.getEvidence(evidenceId);
    
    console.log(chalk.green('✓ Evidence retrieved from blockchain'));
    console.log(chalk.white(`  Name: ${evidence.metadata.name}`));
    console.log(chalk.white(`  Case: ${evidence.caseId}`));
    console.log(chalk.white(`  Type: ${evidence.metadata.type}`));
    console.log(chalk.white(`  Status: ${evidence.status}`));
    console.log(chalk.white(`  Custodian: ${evidence.currentCustodian}`));
    console.log('');

    // Step 2: Log file access
    console.log(chalk.cyan('Step 2: Opening evidence file...'));
    console.log(chalk.gray('─'.repeat(50)));
    
    await simulator.simulateFileAccess(evidenceId);
    console.log(chalk.green('✓ File access logged to blockchain'));
    console.log('');

    // Pause for effect
    await delay(2000);

    // Step 3: Extract artifacts
    console.log(chalk.cyan('Step 3: Extracting digital artifacts...'));
    console.log(chalk.gray('─'.repeat(50)));
    
    const artifactTypes = [
      'browser_history',
      'cookies',
      'email_messages',
      'documents',
      'images',
      'registry_keys',
    ];
    
    const artifacts = await simulator.simulateArtifactExtraction(evidenceId, artifactTypes);
    console.log(chalk.green(`✓ ${artifacts.length} artifacts extracted and logged`));
    console.log('');

    // Pause for effect
    await delay(2000);

    // Step 4: Complete analysis
    console.log(chalk.cyan('Step 4: Completing forensic analysis...'));
    console.log(chalk.gray('─'.repeat(50)));
    
    await simulator.logAction({
      actionType: 'ANALYSIS_COMPLETE',
      evidenceId,
      details: {
        findings: 'Analysis complete. Found browser artifacts indicating suspicious activity.',
        artifactCount: artifacts.length,
        methodology: 'Standard forensic examination following NIST guidelines',
        tools: ['File carving', 'Registry analysis', 'Browser forensics'],
      },
    });
    
    console.log(chalk.green('✓ Analysis completion logged to blockchain'));
    console.log('');

    // Summary
    console.log(chalk.cyan.bold('═'.repeat(60)));
    console.log(chalk.cyan.bold('                     DEMO COMPLETE'));
    console.log(chalk.cyan.bold('═'.repeat(60)));
    console.log('');
    console.log(chalk.white('All forensic actions have been automatically logged to the'));
    console.log(chalk.white('blockchain-based Chain-of-Custody system. The following'));
    console.log(chalk.white('events were recorded:'));
    console.log('');
    console.log(chalk.gray('  1. FILE_ACCESSED - Evidence file opened'));
    console.log(chalk.gray('  2. ARTIFACT_EXTRACTED - 6 artifact types discovered'));
    console.log(chalk.gray('  3. ANALYSIS_COMPLETE - Full analysis documented'));
    console.log('');
    console.log(chalk.yellow('View the complete audit trail in the Evidentia UI:'));
    console.log(chalk.blue(`  http://localhost:3000/audit/${evidenceId}`));
    console.log('');

  } catch (error: any) {
    console.log(chalk.red(`\n❌ Demo failed: ${error.message}`));
    console.log('');
    console.log(chalk.yellow('Make sure:'));
    console.log(chalk.gray('  1. The backend server is running (npm run dev in backend/)'));
    console.log(chalk.gray('  2. Evidence with the specified ID exists'));
    console.log(chalk.gray('  3. The API key is valid'));
    console.log('');
    console.log(chalk.gray(`Usage: npm run demo -- <evidenceId>`));
    process.exit(1);
  }
}

function delay(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Run the demo
runDemo();

