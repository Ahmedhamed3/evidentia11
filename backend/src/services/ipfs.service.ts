/**
 * IPFS Service
 * 
 * Handles evidence storage on IPFS with encryption.
 * Design Decision: Evidence is encrypted with AES-256-GCM before upload to IPFS.
 * The encryption key is managed separately and the key ID is stored on-chain.
 * 
 * Uses direct HTTP API calls instead of ipfs-http-client for better Windows compatibility.
 */

import axios, { AxiosInstance } from 'axios';
import FormData from 'form-data';
import { logger } from '../config/logger';
import { encryptData, decryptData } from './encryption.service';

let ipfsClient: AxiosInstance | null = null;
let ipfsBaseUrl: string = '';

/**
 * Initializes the IPFS client connection
 */
export async function initializeIPFS(): Promise<void> {
  try {
    const host = process.env.IPFS_HOST || 'localhost';
    const port = process.env.IPFS_PORT || '5001';
    const protocol = process.env.IPFS_PROTOCOL || 'http';
    
    ipfsBaseUrl = `${protocol}://${host}:${port}/api/v0`;
    
    ipfsClient = axios.create({
      baseURL: ipfsBaseUrl,
      timeout: 60000, // 60 second timeout for large files
    });
    
    // Test connection by getting version
    const response = await ipfsClient.post('/version');
    logger.info(`Connected to IPFS node version ${response.data.Version}`);
    
  } catch (error) {
    logger.error('Failed to initialize IPFS client:', error);
    // Don't throw - allow running without IPFS for testing
    logger.warn('Running without IPFS connectivity. Evidence upload will fail.');
  }
}

/**
 * Gets the IPFS client instance
 */
export function getIPFSClient(): AxiosInstance {
  if (!ipfsClient) {
    throw new Error('IPFS client not initialized. Call initializeIPFS first.');
  }
  return ipfsClient;
}

/**
 * Uploads evidence to IPFS with encryption
 * @param data - The raw evidence data
 * @param encryptionKeyId - The key ID to use for encryption
 * @returns The IPFS CID of the encrypted data
 */
export async function uploadEvidence(
  data: Buffer,
  encryptionKeyId: string
): Promise<{ cid: string; encryptedSize: number }> {
  const client = getIPFSClient();
  
  // Encrypt the data
  const { encryptedData, iv, authTag } = await encryptData(data, encryptionKeyId);
  
  // Create a package with the encrypted data and metadata needed for decryption
  const package_ = {
    version: 1,
    keyId: encryptionKeyId,
    iv: iv.toString('base64'),
    authTag: authTag.toString('base64'),
    data: encryptedData.toString('base64')
  };
  
  const packageBuffer = Buffer.from(JSON.stringify(package_));
  
  // Upload to IPFS using multipart form
  const formData = new FormData();
  formData.append('file', packageBuffer, {
    filename: 'evidence.enc',
    contentType: 'application/octet-stream'
  });
  
  const response = await client.post('/add?pin=true&cid-version=1', formData, {
    headers: formData.getHeaders(),
    maxContentLength: Infinity,
    maxBodyLength: Infinity
  });
  
  const cid = response.data.Hash;
  logger.info(`Evidence uploaded to IPFS: ${cid}`);
  
  return {
    cid,
    encryptedSize: packageBuffer.length
  };
}

/**
 * Downloads and decrypts evidence from IPFS
 * @param cid - The IPFS CID
 * @param encryptionKeyId - The key ID used for encryption
 * @returns The decrypted evidence data
 */
export async function downloadEvidence(
  cid: string,
  encryptionKeyId: string
): Promise<Buffer> {
  const client = getIPFSClient();
  
  // Download from IPFS
  const response = await client.post(`/cat?arg=${cid}`, null, {
    responseType: 'arraybuffer'
  });
  
  const packageBuffer = Buffer.from(response.data);
  const package_ = JSON.parse(packageBuffer.toString());
  
  // Verify key ID matches
  if (package_.keyId !== encryptionKeyId) {
    throw new Error('Encryption key ID mismatch');
  }
  
  // Decrypt the data
  const encryptedData = Buffer.from(package_.data, 'base64');
  const iv = Buffer.from(package_.iv, 'base64');
  const authTag = Buffer.from(package_.authTag, 'base64');
  
  const decryptedData = await decryptData(
    encryptedData,
    encryptionKeyId,
    iv,
    authTag
  );
  
  logger.info(`Evidence downloaded from IPFS: ${cid}`);
  
  return decryptedData;
}

/**
 * Pins an existing CID to ensure persistence
 */
export async function pinEvidence(cid: string): Promise<void> {
  const client = getIPFSClient();
  await client.post(`/pin/add?arg=${cid}`);
  logger.info(`Evidence pinned: ${cid}`);
}

/**
 * Unpins a CID (for cleanup)
 */
export async function unpinEvidence(cid: string): Promise<void> {
  const client = getIPFSClient();
  await client.post(`/pin/rm?arg=${cid}`);
  logger.info(`Evidence unpinned: ${cid}`);
}

/**
 * Gets information about a stored evidence
 */
export async function getEvidenceInfo(cid: string): Promise<{
  size: number;
  type: string;
}> {
  const client = getIPFSClient();
  
  const response = await client.post(`/files/stat?arg=/ipfs/${cid}`);
  
  return {
    size: response.data.Size,
    type: response.data.Type
  };
}

/**
 * Check if IPFS is available
 */
export function isIPFSAvailable(): boolean {
  return ipfsClient !== null;
}
