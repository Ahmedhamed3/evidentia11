#!/usr/bin/env node
/**
 * Standalone Evidence Decryption Script
 * 
 * This script decrypts evidence files from IPFS.
 * 
 * Usage:
 *   Option 1: Decrypt using IPFS CID and encryption key ID directly
 *     npm run decrypt -- --cid <IPFS_CID> --keyId <ENCRYPTION_KEY_ID> [--output <output_file>]
 * 
 *   Option 2: Decrypt using evidence ID (fetches from blockchain)
 *     npm run decrypt -- --evidenceId <EVIDENCE_ID> [--output <output_file>]
 * 
 * Examples:
 *   npm run decrypt -- --cid QmXxxx... --keyId KEY-xxx-xxx
 *   npm run decrypt -- --evidenceId EVD-12345678
 *   npm run decrypt -- --evidenceId EVD-12345678 --output decrypted_file.bin
 */

import * as crypto from 'crypto';
import axios from 'axios';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: path.join(__dirname, '../.env') });

interface DecryptOptions {
  cid?: string;
  keyId?: string;
  evidenceId?: string;
  output?: string;
  token?: string;
}

interface EvidenceMetadata {
  name?: string;
  mimeType?: string;
}

/**
 * Gets the encryption key for a given key ID
 */
function getKey(keyId: string): Buffer {
  const masterKey = process.env.ENCRYPTION_KEY;
  if (!masterKey) {
    throw new Error('ENCRYPTION_KEY environment variable not set. Check your .env file.');
  }
  
  // Derive a unique key for this keyId using HMAC-SHA256
  const masterKeyBuffer = Buffer.from(masterKey, 'hex');
  const key = crypto.createHmac('sha256', masterKeyBuffer)
    .update(keyId)
    .digest();
  
  return key;
}

/**
 * Decrypts data using AES-256-GCM
 */
function decryptData(
  encryptedData: Buffer,
  keyId: string,
  iv: Buffer,
  authTag: Buffer
): Buffer {
  const key = getKey(keyId);
  
  // Create decipher
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(authTag);
  
  // Decrypt
  const decryptedData = Buffer.concat([
    decipher.update(encryptedData),
    decipher.final()
  ]);
  
  return decryptedData;
}

/**
 * Downloads encrypted package from IPFS
 */
async function downloadFromIPFS(cid: string): Promise<Buffer> {
  const host = process.env.IPFS_HOST || 'localhost';
  const port = process.env.IPFS_PORT || '5001';
  const protocol = process.env.IPFS_PROTOCOL || 'http';
  const ipfsUrl = `${protocol}://${host}:${port}/api/v0/cat?arg=${cid}`;
  
  console.log(`Downloading from IPFS: ${cid}...`);
  
  try {
    const response = await axios.post(ipfsUrl, null, {
      responseType: 'arraybuffer',
      timeout: 60000
    });
    
    return Buffer.from(response.data);
  } catch (error: any) {
    if (error.response) {
      throw new Error(`IPFS error: ${error.response.status} - ${error.response.statusText}`);
    }
    throw new Error(`Failed to download from IPFS: ${error.message}`);
  }
}

/**
 * Detects file type from magic bytes (file signature)
 */
function detectFileType(data: Buffer): { extension: string; mimeType: string } {
  // Check magic bytes for common file types
  if (data.length < 4) {
    return { extension: 'bin', mimeType: 'application/octet-stream' };
  }

  // PDF
  if (data[0] === 0x25 && data[1] === 0x50 && data[2] === 0x44 && data[3] === 0x46) {
    return { extension: 'pdf', mimeType: 'application/pdf' };
  }

  // ZIP (also covers Office documents like .docx, .xlsx)
  if (data[0] === 0x50 && data[1] === 0x4B && (data[2] === 0x03 || data[2] === 0x05 || data[2] === 0x07)) {
    // Check if it's a ZIP-based Office document
    if (data.length > 30) {
      const header = data.toString('utf8', 0, Math.min(30, data.length));
      if (header.includes('word/')) return { extension: 'docx', mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' };
      if (header.includes('xl/')) return { extension: 'xlsx', mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' };
      if (header.includes('ppt/')) return { extension: 'pptx', mimeType: 'application/vnd.openxmlformats-officedocument.presentationml.presentation' };
    }
    return { extension: 'zip', mimeType: 'application/zip' };
  }

  // JPEG
  if (data[0] === 0xFF && data[1] === 0xD8 && data[2] === 0xFF) {
    return { extension: 'jpg', mimeType: 'image/jpeg' };
  }

  // PNG
  if (data[0] === 0x89 && data[1] === 0x50 && data[2] === 0x4E && data[3] === 0x47) {
    return { extension: 'png', mimeType: 'image/png' };
  }

  // GIF
  if (data[0] === 0x47 && data[1] === 0x49 && data[2] === 0x46 && data[3] === 0x38) {
    return { extension: 'gif', mimeType: 'image/gif' };
  }

  // MP4
  if (data.length >= 12 && 
      ((data[4] === 0x66 && data[5] === 0x74 && data[6] === 0x79 && data[7] === 0x70) ||
       (data[8] === 0x66 && data[9] === 0x74 && data[10] === 0x79 && data[11] === 0x70))) {
    return { extension: 'mp4', mimeType: 'video/mp4' };
  }

  // MP3 (ID3v2 or frame sync)
  if ((data[0] === 0x49 && data[1] === 0x44 && data[2] === 0x33) ||
      (data[0] === 0xFF && (data[1] & 0xE0) === 0xE0)) {
    return { extension: 'mp3', mimeType: 'audio/mpeg' };
  }

  // Windows executable (PE)
  if (data[0] === 0x4D && data[1] === 0x5A) {
    return { extension: 'exe', mimeType: 'application/x-msdownload' };
  }

  // ELF (Linux executable)
  if (data[0] === 0x7F && data[1] === 0x45 && data[2] === 0x4C && data[3] === 0x46) {
    return { extension: 'elf', mimeType: 'application/x-executable' };
  }

  // Text files (check if it's valid UTF-8 or ASCII)
  try {
    const text = data.toString('utf8', 0, Math.min(1024, data.length));
    if (/^[\x20-\x7E\s]*$/.test(text) || Buffer.from(text, 'utf8').equals(data.slice(0, Math.min(1024, data.length)))) {
      // Looks like text, try to detect specific types
      if (text.trim().startsWith('<?xml')) return { extension: 'xml', mimeType: 'application/xml' };
      if (text.trim().startsWith('<!DOCTYPE html') || text.trim().startsWith('<html')) return { extension: 'html', mimeType: 'text/html' };
      if (text.trim().startsWith('{') || text.trim().startsWith('[')) return { extension: 'json', mimeType: 'application/json' };
      return { extension: 'txt', mimeType: 'text/plain' };
    }
  } catch {
    // Not valid text
  }

  // Default: binary
  return { extension: 'bin', mimeType: 'application/octet-stream' };
}

/**
 * Gets evidence details from blockchain via backend API
 */
async function getEvidenceFromAPI(evidenceId: string, token?: string): Promise<{ 
  ipfsHash: string; 
  encryptionKeyId: string;
  evidenceHash?: string;
  metadata?: {
    name?: string;
    mimeType?: string;
  };
}> {
  const apiUrl = process.env.API_URL || 'http://localhost:3001';
  const url = `${apiUrl}/api/evidence/${evidenceId}`;
  
  console.log(`Fetching evidence details from API: ${evidenceId}...`);
  
  const headers: any = {};
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  } else if (process.env.JWT_TOKEN) {
    headers.Authorization = `Bearer ${process.env.JWT_TOKEN}`;
  }
  
  try {
    const response = await axios.get(url, { headers });
    const evidence = response.data.data;
    return {
      ipfsHash: evidence.ipfsHash,
      encryptionKeyId: evidence.encryptionKeyId,
      evidenceHash: evidence.evidenceHash,
      metadata: evidence.metadata
    };
  } catch (error: any) {
    if (error.response) {
      if (error.response.status === 401) {
        throw new Error(`Authentication required. Please provide a JWT token using --token <TOKEN> or set JWT_TOKEN environment variable.\nTo get a token, log in via the frontend or API: POST ${apiUrl}/api/auth/login`);
      }
      throw new Error(`API error: ${error.response.status} - ${error.response.data?.error || error.response.statusText}`);
    }
    throw new Error(`Failed to fetch evidence: ${error.message}`);
  }
}

/**
 * Main decryption function
 */
async function decryptEvidence(options: DecryptOptions): Promise<void> {
  let cid: string;
  let keyId: string;
  let metadata: { name?: string; mimeType?: string } | undefined;
  let storedHash: string | undefined;
  
  // Get CID and keyId either directly or from evidence ID
  if (options.evidenceId) {
    const evidence = await getEvidenceFromAPI(options.evidenceId, options.token);
    cid = evidence.ipfsHash;
    keyId = evidence.encryptionKeyId;
    metadata = evidence.metadata;
    storedHash = evidence.evidenceHash;
    console.log(`Evidence ID: ${options.evidenceId}`);
  } else if (options.cid && options.keyId) {
    cid = options.cid;
    keyId = options.keyId;
  } else {
    throw new Error('Either provide --evidenceId OR both --cid and --keyId');
  }
  
  console.log(`IPFS CID: ${cid}`);
  console.log(`Encryption Key ID: ${keyId}`);
  
  // Download encrypted package from IPFS
  const packageBuffer = await downloadFromIPFS(cid);
  const package_ = JSON.parse(packageBuffer.toString());
  
  // Verify key ID matches
  if (package_.keyId !== keyId) {
    throw new Error(`Encryption key ID mismatch! Expected ${keyId}, got ${package_.keyId}`);
  }
  
  console.log('Encrypted package downloaded successfully');
  console.log(`Package version: ${package_.version}`);
  
  // Extract encrypted components
  const encryptedData = Buffer.from(package_.data, 'base64');
  const iv = Buffer.from(package_.iv, 'base64');
  const authTag = Buffer.from(package_.authTag, 'base64');
  
  console.log(`Encrypted data size: ${encryptedData.length} bytes`);
  console.log('Decrypting...');
  
  // Decrypt
  const decryptedData = decryptData(encryptedData, keyId, iv, authTag);
  
  console.log(`✓ Decryption successful!`);
  console.log(`Decrypted data size: ${decryptedData.length} bytes`);
  
  // Determine output filename
  let outputPath: string;
  if (options.output) {
    outputPath = options.output;
  } else if (metadata?.name) {
    // Use original filename from metadata
    outputPath = metadata.name;
    // Ensure the extension matches if we have MIME type info
    if (metadata.mimeType) {
      const ext = path.extname(outputPath);
      if (!ext) {
        // No extension, try to add one based on MIME type
        const mimeToExt: { [key: string]: string } = {
          'application/pdf': '.pdf',
          'image/jpeg': '.jpg',
          'image/png': '.png',
          'image/gif': '.gif',
          'application/zip': '.zip',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document': '.docx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': '.xlsx',
          'text/plain': '.txt',
          'application/json': '.json',
        };
        const extFromMime = mimeToExt[metadata.mimeType];
        if (extFromMime) {
          outputPath += extFromMime;
        }
      }
    }
  } else {
    // Detect file type from content
    const detected = detectFileType(decryptedData);
    const timestamp = Date.now();
    outputPath = `decrypted_evidence_${timestamp}.${detected.extension}`;
    console.log(`Detected file type: ${detected.mimeType} (${detected.extension})`);
  }
  
  // Save to file
  fs.writeFileSync(outputPath, decryptedData);
  
  console.log(`✓ Decrypted file saved to: ${path.resolve(outputPath)}`);
  
  // Compute hash for verification
  const computedHash = crypto.createHash('sha256').update(decryptedData).digest('hex');
  console.log(`SHA-256 hash (computed): ${computedHash}`);
  
  // Compare with stored hash if available
  if (storedHash) {
    if (computedHash === storedHash) {
      console.log(`✓ Hash verification: PASSED (matches blockchain record)`);
    } else {
      console.log(`✗ Hash verification: FAILED`);
      console.log(`  Stored hash:    ${storedHash}`);
      console.log(`  Computed hash:  ${computedHash}`);
      console.log(`  Warning: The decrypted file does not match the original hash!`);
    }
  } else {
    console.log(`(No stored hash available for comparison - use --evidenceId to verify)`);
  }
}

/**
 * Parse command line arguments
 */
function parseArgs(): DecryptOptions {
  const args = process.argv.slice(2);
  const options: DecryptOptions = {};
  
  // Filter out '--' separator if present
  const filteredArgs = args.filter(arg => arg !== '--');
  
  for (let i = 0; i < filteredArgs.length; i++) {
    const arg = filteredArgs[i];
    
    if (arg === '--cid' && filteredArgs[i + 1]) {
      options.cid = filteredArgs[++i];
    } else if (arg === '--keyId' && filteredArgs[i + 1]) {
      options.keyId = filteredArgs[++i];
    } else if (arg === '--evidenceId' && filteredArgs[i + 1]) {
      options.evidenceId = filteredArgs[++i];
    } else     if (arg === '--output' && filteredArgs[i + 1]) {
      options.output = filteredArgs[++i];
    } else if (arg === '--token' && filteredArgs[i + 1]) {
      options.token = filteredArgs[++i];
    } else if (arg === '--help' || arg === '-h') {
      console.log(`
Evidence Decryption Script

Usage:
  Option 1: Decrypt using IPFS CID and encryption key ID
    npm run decrypt -- --cid <IPFS_CID> --keyId <ENCRYPTION_KEY_ID> [--output <file>]
  
  Option 2: Decrypt using evidence ID (fetches from blockchain)
    npm run decrypt -- --evidenceId <EVIDENCE_ID> [--output <file>]

Options:
  --cid <CID>           IPFS Content ID of the encrypted evidence
  --keyId <KEY_ID>      Encryption key ID (e.g., KEY-xxx-xxx)
  --evidenceId <ID>     Evidence ID (e.g., EVD-12345678) - fetches CID and keyId from API
  --output <file>       Output file path (default: decrypted_evidence_<timestamp>.bin)
  --token <TOKEN>       JWT token for API authentication (or set JWT_TOKEN env var)
  --help, -h            Show this help message

Environment Variables (from .env):
  ENCRYPTION_KEY        Master encryption key (hex format)
  IPFS_HOST             IPFS host (default: localhost)
  IPFS_PORT             IPFS port (default: 5001)
  API_URL               Backend API URL (default: http://localhost:3001)
  JWT_TOKEN             JWT token for API authentication (alternative to --token flag)

Examples:
  # Using CID and keyId directly (no authentication needed)
  # PowerShell: Quote each argument separately
  npm run decrypt -- "--cid" "QmXxxx..." "--keyId" "KEY-xxx-xxx"
  
  # Alternative: Use npx directly (bypasses npm argument issues)
  npx ts-node scripts/decrypt-evidence.ts --cid QmXxxx... --keyId KEY-xxx-xxx
  
  # Using evidence ID with token
  npm run decrypt -- "--evidenceId" "EVD-12345678" "--token" "<your-jwt-token>"
  
  # Using evidence ID with token from environment variable
  $env:JWT_TOKEN="<your-jwt-token>"; npm run decrypt -- "--evidenceId" "EVD-12345678"
  
  # With custom output file
  npm run decrypt -- "--evidenceId" "EVD-12345678" "--token" "<token>" "--output" "my_evidence.bin"

Note: To get a JWT token, log in via the frontend or API:
  POST http://localhost:3001/api/auth/login
  Body: { "username": "officer-le-001", "password": "password123" }
  
PowerShell Tip: When using npm run, quote each argument separately to avoid parsing issues.
      `);
      process.exit(0);
    } else if (!arg.startsWith('--') && !options.evidenceId && !options.cid) {
      // Fallback: if we see a bare argument that looks like an evidence ID, treat it as such
      if (arg.match(/^EVD-[A-F0-9]+$/i)) {
        options.evidenceId = arg;
      }
    }
  }
  
  return options;
}

// Main execution
async function main() {
  try {
    const options = parseArgs();
    
    // Debug: show what was parsed
    if (process.env.DEBUG || (!options.cid && !options.keyId && !options.evidenceId)) {
      console.error('Debug: Received arguments:', JSON.stringify(process.argv.slice(2), null, 2));
      console.error('Debug: Parsed options:', JSON.stringify(options, null, 2));
    }
    
    // If no options provided, check if first argument is an evidence ID
    if (!options.cid && !options.keyId && !options.evidenceId) {
      const args = process.argv.slice(2).filter(arg => arg !== '--');
      if (args.length > 0 && args[0].match(/^EVD-[A-F0-9]+$/i)) {
        options.evidenceId = args[0];
      } else {
        console.error('Error: Must provide either --evidenceId OR both --cid and --keyId');
        console.error('Received arguments:', args);
        console.error('Run with --help for usage information');
        console.error('');
        console.error('Note: In PowerShell, you may need to quote arguments:');
        console.error('  npm run decrypt -- "--cid" "QmXxxx..." "--keyId" "KEY-xxx-xxx"');
        process.exit(1);
      }
    }
    
    await decryptEvidence(options);
    console.log('\n✓ Decryption completed successfully!');
    
  } catch (error: any) {
    console.error('\n✗ Error:', error.message);
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  main();
}

