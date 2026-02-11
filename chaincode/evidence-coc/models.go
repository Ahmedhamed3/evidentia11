// Copyright Evidentia Chain-of-Custody System
// Data models for the Evidence Chain-of-Custody system
//
// Design Decision: The paper describes evidence lifecycle but doesn't provide
// exact schemas. These models are designed based on digital forensics best practices
// and the paper's requirements for tracking evidence through its lifecycle.

package main

import "encoding/json"

// EvidenceStatus represents the current state of evidence in its lifecycle
type EvidenceStatus string

const (
	StatusRegistered  EvidenceStatus = "REGISTERED"   // Initial registration
	StatusInCustody   EvidenceStatus = "IN_CUSTODY"   // Under active custody
	StatusInAnalysis  EvidenceStatus = "IN_ANALYSIS"  // Being analyzed by forensic lab
	StatusAnalyzed    EvidenceStatus = "ANALYZED"     // Analysis complete
	StatusUnderReview EvidenceStatus = "UNDER_REVIEW" // Submitted for judicial review
	StatusAdmitted    EvidenceStatus = "ADMITTED"     // Admitted by court
	StatusRejected    EvidenceStatus = "REJECTED"     // Rejected by court
	StatusArchived    EvidenceStatus = "ARCHIVED"     // Case closed, archived
	StatusDisposed    EvidenceStatus = "DISPOSED"     // Evidence disposed
)

// EventType represents the type of custody event
type EventType string

const (
	EventRegistration    EventType = "REGISTRATION"
	EventTransfer        EventType = "TRANSFER"
	EventAccessRequest   EventType = "ACCESS_REQUEST"
	EventAccessGranted   EventType = "ACCESS_GRANTED"
	EventAccessDenied    EventType = "ACCESS_DENIED"
	EventAnalysisStart   EventType = "ANALYSIS_START"
	EventAnalysisEnd     EventType = "ANALYSIS_END"
	EventTagAdded        EventType = "TAG_ADDED"
	EventStatusChange    EventType = "STATUS_CHANGE"
	EventJudicialSubmit  EventType = "JUDICIAL_SUBMIT"
	EventJudicialDecision EventType = "JUDICIAL_DECISION"
	EventExport          EventType = "EXPORT"
	EventVerification    EventType = "VERIFICATION"
)

// Role represents user roles in the system
// Design Decision: Paper mentions roles but doesn't define exact permissions.
// Implementing standard forensic workflow roles with least-privilege principle.
type Role string

const (
	RoleCollector     Role = "COLLECTOR"      // Can register evidence, initiate transfers
	RoleAnalyst       Role = "ANALYST"        // Can analyze evidence, record findings
	RoleSupervisor    Role = "SUPERVISOR"     // Can approve transfers, submit for review
	RoleLegalCounsel  Role = "LEGAL_COUNSEL"  // Can make judicial decisions
	RoleJudge         Role = "JUDGE"          // Can make final admissibility decisions
	RoleAuditor       Role = "AUDITOR"        // Read-only access to audit trails
	RoleAdmin         Role = "ADMIN"          // System administration
)

// Evidence represents a piece of digital evidence
type Evidence struct {
	DocType           string         `json:"docType"`           // For CouchDB queries
	ID                string         `json:"id"`                // Unique evidence identifier
	CaseID            string         `json:"caseId"`            // Associated case number
	IPFSHash          string         `json:"ipfsHash"`          // IPFS CID of encrypted evidence
	EvidenceHash      string         `json:"evidenceHash"`      // SHA-256 hash of original file
	EncryptionKeyID   string         `json:"encryptionKeyId"`   // Reference to encryption key
	Metadata          EvidenceMetadata `json:"metadata"`        // Evidence metadata
	Status            EvidenceStatus `json:"status"`            // Current status
	CurrentCustodian  string         `json:"currentCustodian"`  // Current custodian ID
	CurrentOrg        string         `json:"currentOrg"`        // Current organization MSP ID
	RegisteredBy      string         `json:"registeredBy"`      // Original registrant
	CreatedAt         int64          `json:"createdAt"`         // Unix timestamp
	UpdatedAt         int64          `json:"updatedAt"`         // Unix timestamp
	Tags              []string       `json:"tags"`              // Classification tags
	IntegrityVerified bool           `json:"integrityVerified"` // Last verification status
	LastVerifiedAt    int64          `json:"lastVerifiedAt"`    // Last verification timestamp
}

// EvidenceMetadata contains descriptive information about evidence
type EvidenceMetadata struct {
	Name            string `json:"name"`            // Original filename or description
	Type            string `json:"type"`            // Evidence type (disk image, file, memory dump, etc.)
	Size            int64  `json:"size"`            // Size in bytes
	MimeType        string `json:"mimeType"`        // MIME type if applicable
	SourceDevice    string `json:"sourceDevice"`    // Device/source description
	AcquisitionDate int64  `json:"acquisitionDate"` // When evidence was acquired
	AcquisitionTool string `json:"acquisitionTool"` // Tool used for acquisition
	AcquisitionNotes string `json:"acquisitionNotes"` // Notes from acquisition
	Location        string `json:"location"`        // Physical/logical location of source
	ExaminerNotes   string `json:"examinerNotes"`   // Additional notes
}

// CustodyEvent represents an event in the chain of custody
type CustodyEvent struct {
	DocType       string    `json:"docType"`       // For CouchDB queries
	EventID       string    `json:"eventId"`       // Unique event identifier
	EvidenceID    string    `json:"evidenceId"`    // Associated evidence ID
	EventType     EventType `json:"eventType"`     // Type of event
	FromEntity    string    `json:"fromEntity"`    // Source entity (if transfer)
	FromOrg       string    `json:"fromOrg"`       // Source organization MSP ID
	ToEntity      string    `json:"toEntity"`      // Destination entity (if transfer)
	ToOrg         string    `json:"toOrg"`         // Destination organization MSP ID
	Reason        string    `json:"reason"`        // Reason for the event
	Details       string    `json:"details"`       // Additional details (JSON string)
	Timestamp     int64     `json:"timestamp"`     // Unix timestamp
	PerformedBy   string    `json:"performedBy"`   // User who performed action
	PerformerOrg  string    `json:"performerOrg"`  // Organization of performer
	PerformerRole Role      `json:"performerRole"` // Role of performer
	TxID          string    `json:"txId"`          // Fabric transaction ID
	BlockNumber   uint64    `json:"blockNumber"`   // Block number (populated post-commit)
	Verified      bool      `json:"verified"`      // Signature/integrity verified
}

// AccessRequest represents a request to access evidence
type AccessRequest struct {
	DocType       string `json:"docType"`       // For CouchDB queries
	RequestID     string `json:"requestId"`     // Unique request identifier
	EvidenceID    string `json:"evidenceId"`    // Evidence being requested
	RequesterID   string `json:"requesterId"`   // User requesting access
	RequesterOrg  string `json:"requesterOrg"`  // Organization of requester
	RequesterRole Role   `json:"requesterRole"` // Role of requester
	Purpose       string `json:"purpose"`       // Stated purpose for access
	RequestedAt   int64  `json:"requestedAt"`   // Request timestamp
	Status        string `json:"status"`        // PENDING, APPROVED, DENIED
	ApprovedBy    string `json:"approvedBy"`    // Approver (if approved)
	ApprovedAt    int64  `json:"approvedAt"`    // Approval timestamp
	DenialReason  string `json:"denialReason"`  // Reason if denied
	ExpiresAt     int64  `json:"expiresAt"`     // Access expiration time
}

// AnalysisRecord represents a forensic analysis session
type AnalysisRecord struct {
	DocType        string   `json:"docType"`        // For CouchDB queries
	AnalysisID     string   `json:"analysisId"`     // Unique analysis identifier
	EvidenceID     string   `json:"evidenceId"`     // Evidence analyzed
	AnalystID      string   `json:"analystId"`      // Analyst who performed analysis
	AnalystOrg     string   `json:"analystOrg"`     // Organization of analyst
	ToolUsed       string   `json:"toolUsed"`       // Forensic tool used
	ToolVersion    string   `json:"toolVersion"`    // Version of tool
	StartTime      int64    `json:"startTime"`      // Analysis start time
	EndTime        int64    `json:"endTime"`        // Analysis end time
	Findings       string   `json:"findings"`       // Summary of findings
	ArtifactsFound []string `json:"artifactsFound"` // List of discovered artifacts
	ReportIPFSHash string   `json:"reportIpfsHash"` // IPFS hash of detailed report
	Methodology    string   `json:"methodology"`    // Analysis methodology used
	Verified       bool     `json:"verified"`       // Findings verified by supervisor
	VerifiedBy     string   `json:"verifiedBy"`     // Supervisor who verified
	VerifiedAt     int64    `json:"verifiedAt"`     // Verification timestamp
}

// JudicialReview represents a judicial review of evidence
type JudicialReview struct {
	DocType         string `json:"docType"`         // For CouchDB queries
	ReviewID        string `json:"reviewId"`        // Unique review identifier
	EvidenceID      string `json:"evidenceId"`      // Evidence under review
	CaseID          string `json:"caseId"`          // Court case identifier
	SubmittedBy     string `json:"submittedBy"`     // Who submitted for review
	SubmittedOrg    string `json:"submittedOrg"`    // Organization of submitter
	SubmittedAt     int64  `json:"submittedAt"`     // Submission timestamp
	CaseNotes       string `json:"caseNotes"`       // Notes for the court
	Decision        string `json:"decision"`        // ADMITTED, REJECTED, PENDING
	DecisionReason  string `json:"decisionReason"`  // Reasoning for decision
	DecidedBy       string `json:"decidedBy"`       // Judge/counsel who decided
	DecidedAt       int64  `json:"decidedAt"`       // Decision timestamp
	CourtReference  string `json:"courtReference"`  // Court document reference
}

// AuditReport represents a generated audit report
type AuditReport struct {
	ReportID       string         `json:"reportId"`       // Unique report identifier
	EvidenceID     string         `json:"evidenceId"`     // Evidence audited
	Evidence       Evidence       `json:"evidence"`       // Evidence snapshot
	CustodyChain   []CustodyEvent `json:"custodyChain"`   // Full custody chain
	AnalysisRecords []AnalysisRecord `json:"analysisRecords"` // All analysis records
	JudicialReviews []JudicialReview `json:"judicialReviews"` // All judicial reviews
	GeneratedAt    int64          `json:"generatedAt"`    // Report generation time
	GeneratedBy    string         `json:"generatedBy"`    // Who generated the report
	IntegrityHash  string         `json:"integrityHash"`  // Hash of report contents
	Verified       bool           `json:"verified"`       // All events verified
}

// SensitiveMetadata stored in private data collection
// Design Decision: Paper mentions private data for sensitive info.
// This includes PII and sensitive investigation details.
type SensitiveMetadata struct {
	EvidenceID        string `json:"evidenceId"`
	VictimInfo        string `json:"victimInfo"`        // Encrypted victim information
	SuspectInfo       string `json:"suspectInfo"`       // Encrypted suspect information
	WitnessInfo       string `json:"witnessInfo"`       // Encrypted witness information
	InvestigationNotes string `json:"investigationNotes"` // Sensitive investigation notes
	ClassificationLevel string `json:"classificationLevel"` // Security classification
}

// Helper methods

// ToJSON converts Evidence to JSON bytes
func (e *Evidence) ToJSON() ([]byte, error) {
	return json.Marshal(e)
}

// ToJSON converts CustodyEvent to JSON bytes
func (c *CustodyEvent) ToJSON() ([]byte, error) {
	return json.Marshal(c)
}

// ToJSON converts AnalysisRecord to JSON bytes
func (a *AnalysisRecord) ToJSON() ([]byte, error) {
	return json.Marshal(a)
}

// ToJSON converts JudicialReview to JSON bytes
func (j *JudicialReview) ToJSON() ([]byte, error) {
	return json.Marshal(j)
}

// ToJSON converts AccessRequest to JSON bytes
func (ar *AccessRequest) ToJSON() ([]byte, error) {
	return json.Marshal(ar)
}

// ToJSON converts AuditReport to JSON bytes
func (r *AuditReport) ToJSON() ([]byte, error) {
	return json.Marshal(r)
}

// Document type constants for CouchDB queries
const (
	DocTypeEvidence       = "evidence"
	DocTypeCustodyEvent   = "custody_event"
	DocTypeAccessRequest  = "access_request"
	DocTypeAnalysisRecord = "analysis_record"
	DocTypeJudicialReview = "judicial_review"
)

