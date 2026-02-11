/**
 * Encryption Service
 * 
 * Handles AES-256-GCM encryption for evidence data.
 * Design Decision: Using AES-256-GCM for authenticated encryption,
 * which provides both confidentiality and integrity verification.
 */

import * as crypto from 'crypto';
import { logger } from '../config/logger';

// Key storage (in production, use HSM or secure key management service)
const keyStore: Map<string, Buffer> = new Map();

/**
 * Gets the encryption key for a given key ID
 * In production, this would integrate with a key management service
 */
function getKey(keyId: string): Buffer {
  // Check if we have this key in our store
  let key = keyStore.get(keyId);
  
  if (!key) {
    // For demo purposes, derive key from master key + keyId
    const masterKey = process.env.ENCRYPTION_KEY;
    if (!masterKey) {
      throw new Error('ENCRYPTION_KEY environment variable not set');
    }
    
    // Derive a unique key for this keyId using HKDF
    const masterKeyBuffer = Buffer.from(masterKey, 'hex');
    key = crypto.createHmac('sha256', masterKeyBuffer)
      .update(keyId)
      .digest();
    
    keyStore.set(keyId, key);
  }
  
  return key;
}

/**
 * Generates a new encryption key ID
 */
export function generateKeyId(): string {
  return `KEY-${crypto.randomUUID()}`;
}

/**
 * Encrypts data using AES-256-GCM
 */
export async function encryptData(
  data: Buffer,
  keyId: string
): Promise<{
  encryptedData: Buffer;
  iv: Buffer;
  authTag: Buffer;
}> {
  const key = getKey(keyId);
  
  // Generate random IV (12 bytes for GCM)
  const iv = crypto.randomBytes(12);
  
  // Create cipher
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  
  // Encrypt
  const encryptedData = Buffer.concat([
    cipher.update(data),
    cipher.final()
  ]);
  
  // Get auth tag
  const authTag = cipher.getAuthTag();
  
  logger.debug(`Encrypted ${data.length} bytes with key ${keyId}`);
  
  return {
    encryptedData,
    iv,
    authTag
  };
}

/**
 * Decrypts data using AES-256-GCM
 */
export async function decryptData(
  encryptedData: Buffer,
  keyId: string,
  iv: Buffer,
  authTag: Buffer
): Promise<Buffer> {
  const key = getKey(keyId);
  
  // Create decipher
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(authTag);
  
  // Decrypt
  const decryptedData = Buffer.concat([
    decipher.update(encryptedData),
    decipher.final()
  ]);
  
  logger.debug(`Decrypted ${encryptedData.length} bytes with key ${keyId}`);
  
  return decryptedData;
}

/**
 * Computes SHA-256 hash of data
 */
export function computeHash(data: Buffer): string {
  return crypto.createHash('sha256').update(data).digest('hex');
}

/**
 * Verifies data against an expected hash
 */
export function verifyHash(data: Buffer, expectedHash: string): boolean {
  const actualHash = computeHash(data);
  return actualHash === expectedHash;
}

/**
 * Generates a secure random string
 */
export function generateSecureId(prefix: string = ''): string {
  const randomPart = crypto.randomBytes(16).toString('hex');
  return prefix ? `${prefix}-${randomPart}` : randomPart;
}

