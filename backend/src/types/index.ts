/**
 * TypeScript type definitions for the Evidentia system
 * Mirrors the Go chaincode models for type safety
 */

// Evidence Status enum
export enum EvidenceStatus {
  REGISTERED = 'REGISTERED',
  IN_CUSTODY = 'IN_CUSTODY',
  IN_ANALYSIS = 'IN_ANALYSIS',
  ANALYZED = 'ANALYZED',
  UNDER_REVIEW = 'UNDER_REVIEW',
  ADMITTED = 'ADMITTED',
  REJECTED = 'REJECTED',
  ARCHIVED = 'ARCHIVED',
  DISPOSED = 'DISPOSED'
}

// Event Types
export enum EventType {
  REGISTRATION = 'REGISTRATION',
  TRANSFER = 'TRANSFER',
  ACCESS_REQUEST = 'ACCESS_REQUEST',
  ACCESS_GRANTED = 'ACCESS_GRANTED',
  ACCESS_DENIED = 'ACCESS_DENIED',
  ANALYSIS_START = 'ANALYSIS_START',
  ANALYSIS_END = 'ANALYSIS_END',
  TAG_ADDED = 'TAG_ADDED',
  STATUS_CHANGE = 'STATUS_CHANGE',
  JUDICIAL_SUBMIT = 'JUDICIAL_SUBMIT',
  JUDICIAL_DECISION = 'JUDICIAL_DECISION',
  EXPORT = 'EXPORT',
  VERIFICATION = 'VERIFICATION'
}

// User Roles
export enum Role {
  COLLECTOR = 'COLLECTOR',
  ANALYST = 'ANALYST',
  SUPERVISOR = 'SUPERVISOR',
  LEGAL_COUNSEL = 'LEGAL_COUNSEL',
  JUDGE = 'JUDGE',
  AUDITOR = 'AUDITOR',
  ADMIN = 'ADMIN'
}

// Evidence Metadata
export interface EvidenceMetadata {
  name: string;
  type: string;
  size: number;
  mimeType: string;
  sourceDevice: string;
  acquisitionDate: number;
  acquisitionTool: string;
  acquisitionNotes: string;
  location: string;
  examinerNotes: string;
}

// Evidence
export interface Evidence {
  docType: string;
  id: string;
  caseId: string;
  ipfsHash: string;
  evidenceHash: string;
  encryptionKeyId: string;
  metadata: EvidenceMetadata;
  status: EvidenceStatus;
  currentCustodian: string;
  currentOrg: string;
  registeredBy: string;
  createdAt: number;
  updatedAt: number;
  tags: string[];
  integrityVerified: boolean;
  lastVerifiedAt: number;
}

// Custody Event
export interface CustodyEvent {
  docType: string;
  eventId: string;
  evidenceId: string;
  eventType: EventType;
  fromEntity: string;
  fromOrg: string;
  toEntity: string;
  toOrg: string;
  reason: string;
  details: string;
  timestamp: number;
  performedBy: string;
  performerOrg: string;
  performerRole: Role;
  txId: string;
  blockNumber: number;
  verified: boolean;
}

// Access Request
export interface AccessRequest {
  docType: string;
  requestId: string;
  evidenceId: string;
  requesterId: string;
  requesterOrg: string;
  requesterRole: Role;
  purpose: string;
  requestedAt: number;
  status: 'PENDING' | 'APPROVED' | 'DENIED';
  approvedBy: string;
  approvedAt: number;
  denialReason: string;
  expiresAt: number;
}

// Analysis Record
export interface AnalysisRecord {
  docType: string;
  analysisId: string;
  evidenceId: string;
  analystId: string;
  analystOrg: string;
  toolUsed: string;
  toolVersion: string;
  startTime: number;
  endTime: number;
  findings: string;
  artifactsFound: string[];
  reportIpfsHash: string;
  methodology: string;
  verified: boolean;
  verifiedBy: string;
  verifiedAt: number;
}

// Judicial Review
export interface JudicialReview {
  docType: string;
  reviewId: string;
  evidenceId: string;
  caseId: string;
  submittedBy: string;
  submittedOrg: string;
  submittedAt: number;
  caseNotes: string;
  decision: 'PENDING' | 'ADMITTED' | 'REJECTED';
  decisionReason: string;
  decidedBy: string;
  decidedAt: number;
  courtReference: string;
}

// Audit Report
export interface AuditReport {
  reportId: string;
  evidenceId: string;
  evidence: Evidence;
  custodyChain: CustodyEvent[];
  analysisRecords: AnalysisRecord[];
  judicialReviews: JudicialReview[];
  generatedAt: number;
  generatedBy: string;
  integrityHash: string;
  verified: boolean;
}

// API Request Types
export interface RegisterEvidenceRequest {
  evidenceId: string;
  caseId: string;
  metadata: Partial<EvidenceMetadata>;
}

export interface TransferCustodyRequest {
  toEntityId: string;
  toOrgMSP: string;
  reason: string;
}

export interface RecordAnalysisRequest {
  toolUsed: string;
  toolVersion: string;
  findings: string;
  artifacts: string[];
  methodology: string;
}

export interface JudicialReviewRequest {
  caseNotes: string;
}

export interface JudicialDecisionRequest {
  decision: 'ADMITTED' | 'REJECTED';
  decisionReason: string;
  courtReference: string;
}

// User/Auth Types
export interface User {
  id: string;
  username: string;
  organization: string;
  mspId: string;
  role: Role;
  commonName: string;
}

export interface AuthToken {
  token: string;
  expiresAt: number;
  user: User;
}

// Forensic Tool Integration Types
export interface ForensicToolAction {
  toolName: string;
  toolVersion: string;
  actionType: string;
  evidenceId: string;
  timestamp: number;
  details: Record<string, unknown>;
  operatorId: string;
}

// API Response Types
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

