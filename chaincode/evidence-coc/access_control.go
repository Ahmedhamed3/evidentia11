// Copyright Evidentia Chain-of-Custody System
// Role-Based Access Control (RBAC) implementation
//
// Design Decision: The paper describes RBAC but doesn't provide exact permission matrix.
// This implementation follows the principle of least privilege based on standard
// digital forensics workflows and the paper's organizational structure.

package main

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/hyperledger/fabric-contract-api-go/v2/contractapi"
)

// Permission represents a specific action that can be performed
type Permission string

const (
	PermRegisterEvidence   Permission = "REGISTER_EVIDENCE"
	PermTransferCustody    Permission = "TRANSFER_CUSTODY"
	PermReceiveCustody     Permission = "RECEIVE_CUSTODY"
	PermRequestAccess      Permission = "REQUEST_ACCESS"
	PermGrantAccess        Permission = "GRANT_ACCESS"
	PermRecordAnalysis     Permission = "RECORD_ANALYSIS"
	PermVerifyAnalysis     Permission = "VERIFY_ANALYSIS"
	PermAddTags            Permission = "ADD_TAGS"
	PermUpdateStatus       Permission = "UPDATE_STATUS"
	PermSubmitForReview    Permission = "SUBMIT_FOR_REVIEW"
	PermRecordDecision     Permission = "RECORD_DECISION"
	PermViewEvidence       Permission = "VIEW_EVIDENCE"
	PermViewAudit          Permission = "VIEW_AUDIT"
	PermGenerateReport     Permission = "GENERATE_REPORT"
	PermExportEvidence     Permission = "EXPORT_EVIDENCE"
	PermVerifyIntegrity    Permission = "VERIFY_INTEGRITY"
)

// RolePermissions defines which permissions each role has
// Design Decision: Based on forensic workflow best practices:
// - Collectors: Register and transfer evidence out
// - Analysts: Receive, analyze, and transfer evidence
// - Supervisors: Oversight, verification, and submission
// - Legal: Judicial decisions
// - Auditors: Read-only access to audit trails
var RolePermissions = map[Role][]Permission{
	RoleCollector: {
		PermRegisterEvidence,
		PermTransferCustody,
		PermRequestAccess,
		PermAddTags,
		PermViewEvidence,
		PermViewAudit,
		PermVerifyIntegrity,
	},
	RoleAnalyst: {
		PermReceiveCustody,
		PermTransferCustody,
		PermRequestAccess,
		PermRecordAnalysis,
		PermAddTags,
		PermSubmitForReview,  // Analysts can submit their completed analysis for review
		PermViewEvidence,
		PermViewAudit,
		PermVerifyIntegrity,
		PermExportEvidence,
	},
	RoleSupervisor: {
		PermRegisterEvidence,
		PermTransferCustody,
		PermReceiveCustody,
		PermRequestAccess,
		PermGrantAccess,
		PermVerifyAnalysis,
		PermAddTags,
		PermUpdateStatus,
		PermSubmitForReview,
		PermViewEvidence,
		PermViewAudit,
		PermGenerateReport,
		PermVerifyIntegrity,
		PermExportEvidence,
	},
	RoleLegalCounsel: {
		PermReceiveCustody,
		PermRequestAccess,
		PermRecordDecision,
		PermViewEvidence,
		PermViewAudit,
		PermGenerateReport,
		PermVerifyIntegrity,
	},
	RoleJudge: {
		PermRecordDecision,
		PermViewEvidence,
		PermViewAudit,
		PermGenerateReport,
		PermVerifyIntegrity,
	},
	RoleAuditor: {
		PermViewEvidence,
		PermViewAudit,
		PermGenerateReport,
		PermVerifyIntegrity,
	},
	RoleAdmin: {
		PermRegisterEvidence,
		PermTransferCustody,
		PermReceiveCustody,
		PermRequestAccess,
		PermGrantAccess,
		PermRecordAnalysis,
		PermVerifyAnalysis,
		PermAddTags,
		PermUpdateStatus,
		PermSubmitForReview,
		PermRecordDecision,
		PermViewEvidence,
		PermViewAudit,
		PermGenerateReport,
		PermExportEvidence,
		PermVerifyIntegrity,
	},
}

// OrganizationPermissions defines which organizations can perform which actions
// Design Decision: Aligns with paper's organizational model
var OrganizationPermissions = map[string][]Permission{
	"LawEnforcementMSP": {
		PermRegisterEvidence,
		PermTransferCustody,
		PermReceiveCustody,
		PermRequestAccess,
		PermGrantAccess,
		PermAddTags,
		PermUpdateStatus,
		PermSubmitForReview,
		PermViewEvidence,
		PermViewAudit,
		PermGenerateReport,
		PermVerifyIntegrity,
		PermExportEvidence,
	},
	"ForensicLabMSP": {
		PermReceiveCustody,
		PermTransferCustody,
		PermRequestAccess,
		PermGrantAccess,
		PermRecordAnalysis,
		PermVerifyAnalysis,
		PermAddTags,
		PermUpdateStatus,
		PermViewEvidence,
		PermViewAudit,
		PermGenerateReport,
		PermVerifyIntegrity,
		PermExportEvidence,
	},
	"JudiciaryMSP": {
		PermReceiveCustody,
		PermRequestAccess,
		PermRecordDecision,
		PermViewEvidence,
		PermViewAudit,
		PermGenerateReport,
		PermVerifyIntegrity,
	},
}

// ClientIdentity holds the parsed client identity information
type ClientIdentity struct {
	ID       string `json:"id"`
	MSPID    string `json:"mspId"`
	Role     Role   `json:"role"`
	CommonName string `json:"commonName"`
}

// GetClientIdentity extracts client identity from the transaction context
func GetClientIdentity(ctx contractapi.TransactionContextInterface) (*ClientIdentity, error) {
	// Get the client identity from stub
	clientID, err := ctx.GetClientIdentity().GetID()
	if err != nil {
		return nil, fmt.Errorf("failed to get client ID: %v", err)
	}

	mspID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return nil, fmt.Errorf("failed to get MSP ID: %v", err)
	}

	// Try to get role from certificate attributes
	// Design Decision: Role is encoded as a certificate attribute "role"
	// If not present, default based on MSP and certificate type
	roleAttr, found, err := ctx.GetClientIdentity().GetAttributeValue("role")
	var role Role
	if err == nil && found {
		role = Role(strings.ToUpper(roleAttr))
	} else {
		// Default role based on organization
		role = getDefaultRoleForOrg(mspID)
	}

	// Get common name from certificate
	cert, err := ctx.GetClientIdentity().GetX509Certificate()
	commonName := ""
	if err == nil && cert != nil {
		commonName = cert.Subject.CommonName
	}

	return &ClientIdentity{
		ID:       clientID,
		MSPID:    mspID,
		Role:     role,
		CommonName: commonName,
	}, nil
}

// getDefaultRoleForOrg returns default role based on organization
// Each organization has an appropriate default role for its typical workflow
func getDefaultRoleForOrg(mspID string) Role {
	switch mspID {
	case "LawEnforcementMSP":
		// LawEnforcement default: SUPERVISOR (can register, transfer, submit for review)
		return RoleSupervisor
	case "ForensicLabMSP":
		// ForensicLab default: ANALYST (can record analysis)
		return RoleAnalyst
	case "JudiciaryMSP":
		// Judiciary default: LEGAL_COUNSEL (can record decisions)
		return RoleLegalCounsel
	default:
		return RoleAuditor // Least privilege default
	}
}

// HasPermission checks if the client has the required permission
func HasPermission(identity *ClientIdentity, permission Permission) bool {
	// Check role-based permission
	rolePerms, exists := RolePermissions[identity.Role]
	if !exists {
		return false
	}

	for _, p := range rolePerms {
		if p == permission {
			// Also verify org-level permission
			return hasOrgPermission(identity.MSPID, permission)
		}
	}

	return false
}

// hasOrgPermission checks if organization is allowed to perform action
func hasOrgPermission(mspID string, permission Permission) bool {
	orgPerms, exists := OrganizationPermissions[mspID]
	if !exists {
		return false
	}

	for _, p := range orgPerms {
		if p == permission {
			return true
		}
	}

	return false
}

// RequirePermission is a helper to check permission and return error if not allowed
func RequirePermission(ctx contractapi.TransactionContextInterface, permission Permission) (*ClientIdentity, error) {
	identity, err := GetClientIdentity(ctx)
	if err != nil {
		return nil, err
	}

	if !HasPermission(identity, permission) {
		return nil, fmt.Errorf("access denied: user %s with role %s does not have permission %s",
			identity.ID, identity.Role, permission)
	}

	return identity, nil
}

// ValidateStatusTransition checks if a status transition is allowed
// Design Decision: Implements a state machine for evidence lifecycle
func ValidateStatusTransition(currentStatus, newStatus EvidenceStatus) error {
	allowedTransitions := map[EvidenceStatus][]EvidenceStatus{
		StatusRegistered: {StatusInCustody},
		StatusInCustody:  {StatusInAnalysis, StatusInCustody, StatusUnderReview, StatusArchived},
		StatusInAnalysis: {StatusAnalyzed, StatusInCustody},
		StatusAnalyzed:   {StatusUnderReview, StatusInCustody, StatusInAnalysis},
		StatusUnderReview: {StatusAdmitted, StatusRejected, StatusInAnalysis},
		StatusAdmitted:   {StatusArchived},
		StatusRejected:   {StatusArchived, StatusInAnalysis},
		StatusArchived:   {StatusDisposed},
		StatusDisposed:   {}, // Terminal state
	}

	allowed, exists := allowedTransitions[currentStatus]
	if !exists {
		return fmt.Errorf("unknown current status: %s", currentStatus)
	}

	for _, s := range allowed {
		if s == newStatus {
			return nil
		}
	}

	return fmt.Errorf("invalid status transition from %s to %s", currentStatus, newStatus)
}

// ValidateCustodyTransfer checks if custody transfer is allowed
func ValidateCustodyTransfer(identity *ClientIdentity, evidence *Evidence, toOrg string) error {
	// Must be current custodian or have transfer permission
	if evidence.CurrentCustodian != identity.ID && evidence.CurrentOrg != identity.MSPID {
		// Check if user is supervisor in the same org
		if identity.Role != RoleSupervisor || identity.MSPID != evidence.CurrentOrg {
			return fmt.Errorf("only current custodian or supervisor can transfer evidence")
		}
	}

	// Validate target organization
	_, exists := OrganizationPermissions[toOrg]
	if !exists {
		return fmt.Errorf("unknown target organization: %s", toOrg)
	}

	// Check if target org can receive evidence
	if !hasOrgPermission(toOrg, PermReceiveCustody) {
		return fmt.Errorf("organization %s cannot receive custody", toOrg)
	}

	return nil
}

// AccessControlList manages fine-grained access control
type AccessControlList struct {
	EvidenceID string            `json:"evidenceId"`
	Entries    []AccessEntry     `json:"entries"`
}

// AccessEntry represents an access control entry
type AccessEntry struct {
	EntityID   string       `json:"entityId"`
	EntityOrg  string       `json:"entityOrg"`
	Permissions []Permission `json:"permissions"`
	GrantedBy  string       `json:"grantedBy"`
	GrantedAt  int64        `json:"grantedAt"`
	ExpiresAt  int64        `json:"expiresAt"`
}

// ToJSON converts AccessControlList to JSON
func (acl *AccessControlList) ToJSON() ([]byte, error) {
	return json.Marshal(acl)
}

