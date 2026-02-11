/**
 * Chaincode Contract Wrapper
 * 
 * Provides typed functions for interacting with the evidence-coc chaincode.
 * This layer abstracts the raw transaction calls into domain-specific operations.
 * 
 * Design Decision: Functions that modify state accept an optional orgMspId parameter
 * to specify which organization's gateway should be used for the transaction.
 * This enables proper multi-org support where each organization has its own identity.
 */

import { 
  evaluateTransaction, 
  submitTransaction,
  submitTransactionAsOrg,
  evaluateTransactionAsOrg 
} from './gateway';
import { 
  Evidence, 
  CustodyEvent, 
  AnalysisRecord, 
  AuditReport,
  EvidenceMetadata 
} from '../types';
import { logger } from '../config/logger';

/**
 * Parses the chaincode response and returns typed data
 */
function parseResponse<T>(result: Uint8Array): T {
  const resultString = Buffer.from(result).toString('utf8');
  if (!resultString) {
    throw new Error('Empty response from chaincode');
  }
  return JSON.parse(resultString) as T;
}

// =============================================================================
// Evidence Registration
// =============================================================================

export async function registerEvidence(
  evidenceId: string,
  caseId: string,
  ipfsHash: string,
  evidenceHash: string,
  encryptionKeyId: string,
  metadata: Partial<EvidenceMetadata>,
  orgMspId?: string
): Promise<void> {
  const metadataJSON = JSON.stringify(metadata);
  
  if (orgMspId) {
    await submitTransactionAsOrg(
      orgMspId,
      'RegisterEvidence',
      evidenceId,
      caseId,
      ipfsHash,
      evidenceHash,
      encryptionKeyId,
      metadataJSON
    );
  } else {
    await submitTransaction(
      'RegisterEvidence',
      evidenceId,
      caseId,
      ipfsHash,
      evidenceHash,
      encryptionKeyId,
      metadataJSON
    );
  }
  
  logger.info(`Evidence registered: ${evidenceId}`);
}

// =============================================================================
// Custody Transfer
// =============================================================================

export async function transferCustody(
  evidenceId: string,
  toEntityId: string,
  toOrgMSP: string,
  reason: string,
  fromOrgMspId?: string
): Promise<void> {
  if (fromOrgMspId) {
    await submitTransactionAsOrg(
      fromOrgMspId,
      'TransferCustody',
      evidenceId,
      toEntityId,
      toOrgMSP,
      reason
    );
  } else {
    await submitTransaction(
      'TransferCustody',
      evidenceId,
      toEntityId,
      toOrgMSP,
      reason
    );
  }
  
  logger.info(`Custody transferred for ${evidenceId} to ${toEntityId}`);
}

// =============================================================================
// Access Management
// =============================================================================

export async function requestAccess(
  evidenceId: string,
  purpose: string,
  orgMspId?: string
): Promise<string> {
  let result: Uint8Array;
  
  if (orgMspId) {
    result = await submitTransactionAsOrg(
      orgMspId,
      'RequestAccess',
      evidenceId,
      purpose
    );
  } else {
    result = await submitTransaction(
      'RequestAccess',
      evidenceId,
      purpose
    );
  }
  
  const requestId = Buffer.from(result).toString('utf8');
  logger.info(`Access requested for ${evidenceId}: ${requestId}`);
  return requestId;
}

export async function grantAccess(
  requestId: string,
  expirationHours: number,
  orgMspId?: string
): Promise<void> {
  if (orgMspId) {
    await submitTransactionAsOrg(
      orgMspId,
      'GrantAccess',
      requestId,
      expirationHours.toString()
    );
  } else {
    await submitTransaction(
      'GrantAccess',
      requestId,
      expirationHours.toString()
    );
  }
  
  logger.info(`Access granted: ${requestId}`);
}

export async function denyAccess(
  requestId: string,
  reason: string,
  orgMspId?: string
): Promise<void> {
  if (orgMspId) {
    await submitTransactionAsOrg(
      orgMspId,
      'DenyAccess',
      requestId,
      reason
    );
  } else {
    await submitTransaction(
      'DenyAccess',
      requestId,
      reason
    );
  }
  
  logger.info(`Access denied: ${requestId}`);
}

// =============================================================================
// Analysis Operations
// =============================================================================

export async function recordAnalysis(
  evidenceId: string,
  toolUsed: string,
  toolVersion: string,
  findings: string,
  artifacts: string[],
  reportIPFSHash: string,
  methodology: string,
  orgMspId?: string
): Promise<string> {
  const artifactsJSON = JSON.stringify(artifacts);
  
  let result: Uint8Array;
  
  // Analysis should be recorded by ForensicLabMSP
  const targetOrg = orgMspId || 'ForensicLabMSP';
  
  result = await submitTransactionAsOrg(
    targetOrg,
    'RecordAnalysis',
    evidenceId,
    toolUsed,
    toolVersion,
    findings,
    artifactsJSON,
    reportIPFSHash,
    methodology
  );
  
  const analysisId = Buffer.from(result).toString('utf8');
  logger.info(`Analysis recorded for ${evidenceId}: ${analysisId}`);
  return analysisId;
}

export async function verifyAnalysis(
  analysisId: string,
  orgMspId?: string
): Promise<void> {
  if (orgMspId) {
    await submitTransactionAsOrg(orgMspId, 'VerifyAnalysis', analysisId);
  } else {
    await submitTransaction('VerifyAnalysis', analysisId);
  }
  logger.info(`Analysis verified: ${analysisId}`);
}

// =============================================================================
// Judicial Review
// =============================================================================

export async function submitForJudicialReview(
  evidenceId: string,
  caseNotes: string,
  orgMspId?: string
): Promise<string> {
  let result: Uint8Array;
  
  if (orgMspId) {
    result = await submitTransactionAsOrg(
      orgMspId,
      'SubmitForJudicialReview',
      evidenceId,
      caseNotes
    );
  } else {
    result = await submitTransaction(
      'SubmitForJudicialReview',
      evidenceId,
      caseNotes
    );
  }
  
  const reviewId = Buffer.from(result).toString('utf8');
  logger.info(`Evidence submitted for judicial review: ${reviewId}`);
  return reviewId;
}

export async function recordJudicialDecision(
  reviewId: string,
  decision: 'ADMITTED' | 'REJECTED',
  decisionReason: string,
  courtReference: string,
  orgMspId?: string
): Promise<void> {
  // Judicial decisions should be recorded by JudiciaryMSP
  const targetOrg = orgMspId || 'JudiciaryMSP';
  
  await submitTransactionAsOrg(
    targetOrg,
    'RecordJudicialDecision',
    reviewId,
    decision,
    decisionReason,
    courtReference
  );
  
  logger.info(`Judicial decision recorded for ${reviewId}: ${decision}`);
}

// =============================================================================
// Evidence Management
// =============================================================================

export async function addTag(
  evidenceId: string, 
  tag: string,
  orgMspId?: string
): Promise<void> {
  if (orgMspId) {
    await submitTransactionAsOrg(orgMspId, 'AddTag', evidenceId, tag);
  } else {
    await submitTransaction('AddTag', evidenceId, tag);
  }
  logger.info(`Tag added to ${evidenceId}: ${tag}`);
}

export async function updateStatus(
  evidenceId: string,
  newStatus: string,
  reason: string,
  orgMspId?: string
): Promise<void> {
  if (orgMspId) {
    await submitTransactionAsOrg(orgMspId, 'UpdateStatus', evidenceId, newStatus, reason);
  } else {
    await submitTransaction('UpdateStatus', evidenceId, newStatus, reason);
  }
  logger.info(`Status updated for ${evidenceId}: ${newStatus}`);
}

export async function verifyIntegrity(
  evidenceId: string,
  providedHash: string,
  orgMspId?: string
): Promise<boolean> {
  let result: Uint8Array;
  
  if (orgMspId) {
    result = await submitTransactionAsOrg(
      orgMspId,
      'VerifyIntegrity',
      evidenceId,
      providedHash
    );
  } else {
    result = await submitTransaction(
      'VerifyIntegrity',
      evidenceId,
      providedHash
    );
  }
  
  const verified = Buffer.from(result).toString('utf8') === 'true';
  logger.info(`Integrity verification for ${evidenceId}: ${verified}`);
  return verified;
}

// =============================================================================
// Query Functions
// =============================================================================

export async function getEvidence(evidenceId: string): Promise<Evidence> {
  const result = await evaluateTransaction('GetEvidence', evidenceId);
  return parseResponse<Evidence>(result);
}

export async function getAllEvidence(): Promise<Evidence[]> {
  const result = await evaluateTransaction('GetAllEvidence');
  return parseResponse<Evidence[]>(result);
}

export async function getEvidenceHistory(evidenceId: string): Promise<CustodyEvent[]> {
  const result = await evaluateTransaction('GetEvidenceHistory', evidenceId);
  return parseResponse<CustodyEvent[]>(result);
}

export async function getEvidenceByCase(caseId: string): Promise<Evidence[]> {
  const result = await evaluateTransaction('GetEvidenceByCase', caseId);
  return parseResponse<Evidence[]>(result);
}

export async function queryByStatus(status: string): Promise<Evidence[]> {
  const result = await evaluateTransaction('QueryByStatus', status);
  return parseResponse<Evidence[]>(result);
}

export async function getAnalysisRecords(evidenceId: string): Promise<AnalysisRecord[]> {
  const result = await evaluateTransaction('GetAnalysisRecords', evidenceId);
  return parseResponse<AnalysisRecord[]>(result);
}

export async function generateAuditReport(evidenceId: string): Promise<AuditReport> {
  const result = await evaluateTransaction('GenerateAuditReport', evidenceId);
  return parseResponse<AuditReport>(result);
}
