/**
 * Hyperledger Fabric Gateway Connection
 * 
 * Manages connections to the Fabric network using the Gateway SDK.
 * Supports multiple organizations with separate gateway connections.
 * Design Decision: Using the new fabric-gateway SDK (v1.x) which is the
 * recommended approach for Fabric 2.4+ applications.
 */

import * as grpc from '@grpc/grpc-js';
import { connect, Contract, Gateway, Identity, Signer, signers } from '@hyperledger/fabric-gateway';
import * as crypto from 'crypto';
import * as fs from 'fs';
import * as path from 'path';
import { fabricConfig } from '../config/fabric.config';
import { logger } from '../config/logger';

// Store gateway connections for each organization
interface OrgConnection {
  gateway: Gateway;
  client: grpc.Client;
  contract: Contract;
}

const orgConnections: Map<string, OrgConnection> = new Map();

// Default organization (fallback)
let defaultOrg: string = 'LawEnforcement';

/**
 * Creates a new gRPC connection to the Fabric peer for a specific organization
 */
async function newGrpcConnection(orgName: string): Promise<grpc.Client> {
  const orgConfigs = fabricConfig.getAllOrgConfigs();
  const orgConfig = orgConfigs[orgName];
  
  if (!orgConfig) {
    throw new Error(`Unknown organization: ${orgName}`);
  }
  
  const tlsRootCert = fs.readFileSync(orgConfig.tlsCertPath);
  const tlsCredentials = grpc.credentials.createSsl(tlsRootCert);
  
  return new grpc.Client(
    orgConfig.peerEndpoint,
    tlsCredentials,
    {
      'grpc.ssl_target_name_override': orgConfig.peerHostAlias,
    }
  );
}

/**
 * Creates a new identity from the user's certificate for a specific organization
 */
async function newIdentity(orgName: string): Promise<Identity> {
  const orgConfigs = fabricConfig.getAllOrgConfigs();
  const orgConfig = orgConfigs[orgName];
  
  if (!orgConfig) {
    throw new Error(`Unknown organization: ${orgName}`);
  }
  
  const certPath = orgConfig.userCertPath;
  const credentials = fs.readFileSync(certPath);
  
  return {
    mspId: orgConfig.mspId,
    credentials,
  };
}

/**
 * Creates a new signer from the user's private key for a specific organization
 */
async function newSigner(orgName: string): Promise<Signer> {
  const orgConfigs = fabricConfig.getAllOrgConfigs();
  const orgConfig = orgConfigs[orgName];
  
  if (!orgConfig) {
    throw new Error(`Unknown organization: ${orgName}`);
  }
  
  const keyDir = orgConfig.userKeyDir;
  const files = fs.readdirSync(keyDir);
  const keyFile = files.find(f => f.endsWith('_sk'));
  
  if (!keyFile) {
    throw new Error(`No private key found in ${keyDir}`);
  }
  
  const keyPath = path.join(keyDir, keyFile);
  const privateKeyPem = fs.readFileSync(keyPath);
  const privateKey = crypto.createPrivateKey(privateKeyPem);
  
  return signers.newPrivateKeySigner(privateKey);
}

/**
 * Initializes a gateway connection for a specific organization
 */
async function initializeOrgGateway(orgName: string): Promise<OrgConnection> {
  const client = await newGrpcConnection(orgName);
  
  const gateway = connect({
    client,
    identity: await newIdentity(orgName),
    signer: await newSigner(orgName),
    evaluateOptions: () => ({ deadline: Date.now() + 5000 }), // 5 seconds
    endorseOptions: () => ({ deadline: Date.now() + 15000 }), // 15 seconds
    submitOptions: () => ({ deadline: Date.now() + 5000 }), // 5 seconds
    commitStatusOptions: () => ({ deadline: Date.now() + 60000 }), // 60 seconds
  });
  
  const network = gateway.getNetwork(fabricConfig.channelName);
  const contract = network.getContract(fabricConfig.chaincodeName);
  
  return { gateway, client, contract };
}

/**
 * Initializes the Fabric Gateway connections for all organizations
 */
export async function initializeFabricGateway(): Promise<void> {
  try {
    const orgConfigs = fabricConfig.getAllOrgConfigs();
    defaultOrg = fabricConfig.organization;
    
    // Initialize gateway for each organization
    for (const orgName of Object.keys(orgConfigs)) {
      try {
        const connection = await initializeOrgGateway(orgName);
        orgConnections.set(orgName, connection);
        logger.info(`Connected to Fabric network for organization: ${orgName}`);
      } catch (error) {
        logger.warn(`Failed to initialize gateway for ${orgName}:`, error);
        // Continue with other organizations
      }
    }
    
    if (orgConnections.size === 0) {
      throw new Error('Failed to initialize any organization gateway');
    }
    
    logger.info(`Connected to Fabric network: ${fabricConfig.channelName}`);
    logger.info(`Using chaincode: ${fabricConfig.chaincodeName}`);
    logger.info(`Organizations initialized: ${Array.from(orgConnections.keys()).join(', ')}`);
    logger.info(`Default organization: ${defaultOrg}`);
    
  } catch (error) {
    logger.error('Failed to initialize Fabric Gateway:', error);
    throw error;
  }
}

/**
 * Disconnects from all Fabric Gateways
 */
export async function disconnectFabricGateway(): Promise<void> {
  for (const [orgName, connection] of orgConnections) {
    connection.gateway.close();
    connection.client.close();
    logger.info(`Disconnected from Fabric Gateway for: ${orgName}`);
  }
  orgConnections.clear();
  logger.info('Disconnected from all Fabric Gateways');
}

/**
 * Maps MSP ID to organization name
 */
function mspIdToOrgName(mspId: string): string {
  const mapping: Record<string, string> = {
    'LawEnforcementMSP': 'LawEnforcement',
    'ForensicLabMSP': 'ForensicLab',
    'JudiciaryMSP': 'Judiciary',
  };
  return mapping[mspId] || mspId;
}

/**
 * Gets the contract instance for a specific organization
 */
export function getContractForOrg(orgMspId?: string): Contract {
  let orgName = defaultOrg;
  
  if (orgMspId) {
    orgName = mspIdToOrgName(orgMspId);
  }
  
  const connection = orgConnections.get(orgName);
  
  if (!connection) {
    // Fallback to default org if requested org not available
    const defaultConnection = orgConnections.get(defaultOrg);
    if (!defaultConnection) {
      throw new Error(`Fabric Gateway not initialized for organization: ${orgName}`);
    }
    logger.warn(`Organization ${orgName} not available, using ${defaultOrg}`);
    return defaultConnection.contract;
  }
  
  return connection.contract;
}

/**
 * Gets the contract instance (uses default organization)
 */
export function getContract(): Contract {
  return getContractForOrg(undefined);
}

/**
 * Gets the gateway instance for a specific organization
 */
export function getGatewayForOrg(orgMspId?: string): Gateway {
  let orgName = defaultOrg;
  
  if (orgMspId) {
    orgName = mspIdToOrgName(orgMspId);
  }
  
  const connection = orgConnections.get(orgName);
  
  if (!connection) {
    const defaultConnection = orgConnections.get(defaultOrg);
    if (!defaultConnection) {
      throw new Error(`Fabric Gateway not initialized for organization: ${orgName}`);
    }
    return defaultConnection.gateway;
  }
  
  return connection.gateway;
}

/**
 * Gets the gateway instance (uses default organization)
 */
export function getGateway(): Gateway {
  return getGatewayForOrg(undefined);
}

/**
 * Evaluates a chaincode transaction (read-only) using specific organization
 */
export async function evaluateTransaction(
  functionName: string,
  ...args: string[]
): Promise<Uint8Array> {
  const contract = getContract();
  
  logger.debug(`Evaluating transaction: ${functionName}`, { args });
  
  try {
    const result = await contract.evaluateTransaction(functionName, ...args);
    return result;
  } catch (error) {
    logger.error(`Failed to evaluate transaction ${functionName}:`, error);
    throw error;
  }
}

/**
 * Evaluates a chaincode transaction using a specific organization's gateway
 */
export async function evaluateTransactionAsOrg(
  orgMspId: string,
  functionName: string,
  ...args: string[]
): Promise<Uint8Array> {
  const contract = getContractForOrg(orgMspId);
  
  logger.debug(`Evaluating transaction as ${orgMspId}: ${functionName}`, { args });
  
  try {
    const result = await contract.evaluateTransaction(functionName, ...args);
    return result;
  } catch (error) {
    logger.error(`Failed to evaluate transaction ${functionName} as ${orgMspId}:`, error);
    throw error;
  }
}

/**
 * Submits a chaincode transaction (read-write) using default organization
 */
export async function submitTransaction(
  functionName: string,
  ...args: string[]
): Promise<Uint8Array> {
  const contract = getContract();
  
  logger.debug(`Submitting transaction: ${functionName}`, { args });
  
  try {
    const result = await contract.submitTransaction(functionName, ...args);
    logger.info(`Transaction ${functionName} submitted successfully`);
    return result;
  } catch (error) {
    logger.error(`Failed to submit transaction ${functionName}:`, error);
    throw error;
  }
}

/**
 * Submits a chaincode transaction using a specific organization's gateway
 */
export async function submitTransactionAsOrg(
  orgMspId: string,
  functionName: string,
  ...args: string[]
): Promise<Uint8Array> {
  const contract = getContractForOrg(orgMspId);
  
  logger.debug(`Submitting transaction as ${orgMspId}: ${functionName}`, { args });
  
  try {
    const result = await contract.submitTransaction(functionName, ...args);
    logger.info(`Transaction ${functionName} submitted successfully as ${orgMspId}`);
    return result;
  } catch (error) {
    logger.error(`Failed to submit transaction ${functionName} as ${orgMspId}:`, error);
    throw error;
  }
}

/**
 * Gets the list of initialized organizations
 */
export function getInitializedOrgs(): string[] {
  return Array.from(orgConnections.keys());
}
