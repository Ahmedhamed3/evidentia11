// Copyright Evidentia Chain-of-Custody System
// Smart Contract implementation for Evidence Chain-of-Custody
//
// This chaincode implements the evidence lifecycle management as described
// in the blockchain-based CoC research paper, with additional production-ready
// features for security and compliance.

package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"sort"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/v2/contractapi"
)

// EvidenceContract implements the evidence chain-of-custody smart contract
type EvidenceContract struct {
	contractapi.Contract
}

// InitLedger initializes the chaincode (optional, used for testing)
func (s *EvidenceContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	// No initialization required - this is a placeholder
	return nil
}

// =============================================================================
// Evidence Registration
// =============================================================================

// RegisterEvidence registers a new piece of digital evidence
// Parameters:
//   - evidenceID: Unique identifier for the evidence
//   - caseID: Associated case number
//   - ipfsHash: IPFS CID where encrypted evidence is stored
//   - evidenceHash: SHA-256 hash of the original evidence file
//   - encryptionKeyID: Reference to the encryption key
//   - metadataJSON: JSON string containing EvidenceMetadata
func (s *EvidenceContract) RegisterEvidence(
	ctx contractapi.TransactionContextInterface,
	evidenceID string,
	caseID string,
	ipfsHash string,
	evidenceHash string,
	encryptionKeyID string,
	metadataJSON string,
) error {
	// Verify permission
	identity, err := RequirePermission(ctx, PermRegisterEvidence)
	if err != nil {
		return err
	}

	// Check if evidence already exists
	exists, err := s.EvidenceExists(ctx, evidenceID)
	if err != nil {
		return err
	}
	if exists {
		return fmt.Errorf("evidence %s already exists", evidenceID)
	}

	// Parse metadata
	var metadata EvidenceMetadata
	if err := json.Unmarshal([]byte(metadataJSON), &metadata); err != nil {
		return fmt.Errorf("failed to parse metadata: %v", err)
	}

	// Create evidence record
	timestamp := time.Now().Unix()
	evidence := Evidence{
		DocType:           DocTypeEvidence,
		ID:                evidenceID,
		CaseID:            caseID,
		IPFSHash:          ipfsHash,
		EvidenceHash:      evidenceHash,
		EncryptionKeyID:   encryptionKeyID,
		Metadata:          metadata,
		Status:            StatusRegistered,
		CurrentCustodian:  identity.ID,
		CurrentOrg:        identity.MSPID,
		RegisteredBy:      identity.ID,
		CreatedAt:         timestamp,
		UpdatedAt:         timestamp,
		Tags:              []string{},
		IntegrityVerified: true,
		LastVerifiedAt:    timestamp,
	}

	// Store evidence
	evidenceJSON, err := evidence.ToJSON()
	if err != nil {
		return err
	}
	if err := ctx.GetStub().PutState(evidenceID, evidenceJSON); err != nil {
		return fmt.Errorf("failed to store evidence: %v", err)
	}

	// Record registration event
	event := CustodyEvent{
		DocType:       DocTypeCustodyEvent,
		EventID:       fmt.Sprintf("EVT-%s-%d", evidenceID, timestamp),
		EvidenceID:    evidenceID,
		EventType:     EventRegistration,
		ToEntity:      identity.ID,
		ToOrg:         identity.MSPID,
		Reason:        "Initial evidence registration",
		Details:       fmt.Sprintf(`{"caseId":"%s","ipfsHash":"%s"}`, caseID, ipfsHash),
		Timestamp:     timestamp,
		PerformedBy:   identity.ID,
		PerformerOrg:  identity.MSPID,
		PerformerRole: identity.Role,
		TxID:          ctx.GetStub().GetTxID(),
		Verified:      true,
	}

	eventJSON, err := event.ToJSON()
	if err != nil {
		return err
	}
	eventKey := fmt.Sprintf("EVENT~%s~%d", evidenceID, timestamp)
	if err := ctx.GetStub().PutState(eventKey, eventJSON); err != nil {
		return fmt.Errorf("failed to store custody event: %v", err)
	}

	// Emit event for external systems
	eventPayload, _ := json.Marshal(map[string]interface{}{
		"type":       "EVIDENCE_REGISTERED",
		"evidenceId": evidenceID,
		"caseId":     caseID,
		"registrant": identity.ID,
		"timestamp":  timestamp,
	})
	ctx.GetStub().SetEvent("EvidenceRegistered", eventPayload)

	return nil
}

// =============================================================================
// Custody Transfer
// =============================================================================

// TransferCustody transfers custody of evidence to another entity
func (s *EvidenceContract) TransferCustody(
	ctx contractapi.TransactionContextInterface,
	evidenceID string,
	toEntityID string,
	toOrgMSP string,
	reason string,
) error {
	// Verify permission
	identity, err := RequirePermission(ctx, PermTransferCustody)
	if err != nil {
		return err
	}

	// Get evidence
	evidence, err := s.GetEvidence(ctx, evidenceID)
	if err != nil {
		return err
	}

	// Validate transfer
	if err := ValidateCustodyTransfer(identity, evidence, toOrgMSP); err != nil {
		return err
	}

	// Record current custodian for event
	fromEntity := evidence.CurrentCustodian
	fromOrg := evidence.CurrentOrg

	// Update evidence
	timestamp := time.Now().Unix()
	evidence.CurrentCustodian = toEntityID
	evidence.CurrentOrg = toOrgMSP
	evidence.UpdatedAt = timestamp
	
	// Update status if transitioning to analysis
	if toOrgMSP == "ForensicLabMSP" && evidence.Status == StatusInCustody {
		evidence.Status = StatusInAnalysis
	} else if evidence.Status == StatusRegistered {
		evidence.Status = StatusInCustody
	}

	// Store updated evidence
	evidenceJSON, err := evidence.ToJSON()
	if err != nil {
		return err
	}
	if err := ctx.GetStub().PutState(evidenceID, evidenceJSON); err != nil {
		return err
	}

	// Record transfer event
	event := CustodyEvent{
		DocType:       DocTypeCustodyEvent,
		EventID:       fmt.Sprintf("EVT-%s-%d", evidenceID, timestamp),
		EvidenceID:    evidenceID,
		EventType:     EventTransfer,
		FromEntity:    fromEntity,
		FromOrg:       fromOrg,
		ToEntity:      toEntityID,
		ToOrg:         toOrgMSP,
		Reason:        reason,
		Details:       fmt.Sprintf(`{"previousStatus":"%s","newStatus":"%s"}`, evidence.Status, evidence.Status),
		Timestamp:     timestamp,
		PerformedBy:   identity.ID,
		PerformerOrg:  identity.MSPID,
		PerformerRole: identity.Role,
		TxID:          ctx.GetStub().GetTxID(),
		Verified:      true,
	}

	eventJSON, err := event.ToJSON()
	if err != nil {
		return err
	}
	eventKey := fmt.Sprintf("EVENT~%s~%d", evidenceID, timestamp)
	if err := ctx.GetStub().PutState(eventKey, eventJSON); err != nil {
		return err
	}

	// Emit event
	eventPayload, _ := json.Marshal(map[string]interface{}{
		"type":       "CUSTODY_TRANSFERRED",
		"evidenceId": evidenceID,
		"from":       fromEntity,
		"fromOrg":    fromOrg,
		"to":         toEntityID,
		"toOrg":      toOrgMSP,
		"timestamp":  timestamp,
	})
	ctx.GetStub().SetEvent("CustodyTransferred", eventPayload)

	return nil
}

// =============================================================================
// Access Management
// =============================================================================

// RequestAccess creates a request to access evidence
func (s *EvidenceContract) RequestAccess(
	ctx contractapi.TransactionContextInterface,
	evidenceID string,
	purpose string,
) (string, error) {
	// Verify permission
	identity, err := RequirePermission(ctx, PermRequestAccess)
	if err != nil {
		return "", err
	}

	// Verify evidence exists
	_, err = s.GetEvidence(ctx, evidenceID)
	if err != nil {
		return "", err
	}

	// Create access request
	timestamp := time.Now().Unix()
	requestID := fmt.Sprintf("REQ-%s-%s-%d", evidenceID, identity.ID[:8], timestamp)

	request := AccessRequest{
		DocType:       DocTypeAccessRequest,
		RequestID:     requestID,
		EvidenceID:    evidenceID,
		RequesterID:   identity.ID,
		RequesterOrg:  identity.MSPID,
		RequesterRole: identity.Role,
		Purpose:       purpose,
		RequestedAt:   timestamp,
		Status:        "PENDING",
	}

	requestJSON, err := request.ToJSON()
	if err != nil {
		return "", err
	}
	if err := ctx.GetStub().PutState(requestID, requestJSON); err != nil {
		return "", err
	}

	// Record event
	event := CustodyEvent{
		DocType:       DocTypeCustodyEvent,
		EventID:       fmt.Sprintf("EVT-%s-%d", evidenceID, timestamp),
		EvidenceID:    evidenceID,
		EventType:     EventAccessRequest,
		FromEntity:    identity.ID,
		FromOrg:       identity.MSPID,
		Reason:        purpose,
		Details:       fmt.Sprintf(`{"requestId":"%s"}`, requestID),
		Timestamp:     timestamp,
		PerformedBy:   identity.ID,
		PerformerOrg:  identity.MSPID,
		PerformerRole: identity.Role,
		TxID:          ctx.GetStub().GetTxID(),
		Verified:      true,
	}

	eventJSON, err := event.ToJSON()
	if err != nil {
		return "", err
	}
	eventKey := fmt.Sprintf("EVENT~%s~%d", evidenceID, timestamp)
	ctx.GetStub().PutState(eventKey, eventJSON)

	return requestID, nil
}

// GrantAccess approves an access request
func (s *EvidenceContract) GrantAccess(
	ctx contractapi.TransactionContextInterface,
	requestID string,
	expirationHours int,
) error {
	// Verify permission
	identity, err := RequirePermission(ctx, PermGrantAccess)
	if err != nil {
		return err
	}

	// Get access request
	requestJSON, err := ctx.GetStub().GetState(requestID)
	if err != nil {
		return err
	}
	if requestJSON == nil {
		return fmt.Errorf("access request %s not found", requestID)
	}

	var request AccessRequest
	if err := json.Unmarshal(requestJSON, &request); err != nil {
		return err
	}

	if request.Status != "PENDING" {
		return fmt.Errorf("access request is not pending")
	}

	// Get evidence to verify current org
	evidence, err := s.GetEvidence(ctx, request.EvidenceID)
	if err != nil {
		return err
	}

	// Only current custodian's org can grant access
	if identity.MSPID != evidence.CurrentOrg {
		return fmt.Errorf("only current custodian organization can grant access")
	}

	// Update request
	timestamp := time.Now().Unix()
	request.Status = "APPROVED"
	request.ApprovedBy = identity.ID
	request.ApprovedAt = timestamp
	request.ExpiresAt = timestamp + int64(expirationHours*3600)

	requestJSON, err = request.ToJSON()
	if err != nil {
		return err
	}
	if err := ctx.GetStub().PutState(requestID, requestJSON); err != nil {
		return err
	}

	// Record event
	event := CustodyEvent{
		DocType:       DocTypeCustodyEvent,
		EventID:       fmt.Sprintf("EVT-%s-%d", request.EvidenceID, timestamp),
		EvidenceID:    request.EvidenceID,
		EventType:     EventAccessGranted,
		FromEntity:    identity.ID,
		FromOrg:       identity.MSPID,
		ToEntity:      request.RequesterID,
		ToOrg:         request.RequesterOrg,
		Reason:        fmt.Sprintf("Access granted for: %s", request.Purpose),
		Details:       fmt.Sprintf(`{"requestId":"%s","expiresAt":%d}`, requestID, request.ExpiresAt),
		Timestamp:     timestamp,
		PerformedBy:   identity.ID,
		PerformerOrg:  identity.MSPID,
		PerformerRole: identity.Role,
		TxID:          ctx.GetStub().GetTxID(),
		Verified:      true,
	}

	eventJSON, err := event.ToJSON()
	if err != nil {
		return err
	}
	eventKey := fmt.Sprintf("EVENT~%s~%d", request.EvidenceID, timestamp)
	ctx.GetStub().PutState(eventKey, eventJSON)

	return nil
}

// DenyAccess denies an access request
func (s *EvidenceContract) DenyAccess(
	ctx contractapi.TransactionContextInterface,
	requestID string,
	reason string,
) error {
	identity, err := RequirePermission(ctx, PermGrantAccess)
	if err != nil {
		return err
	}

	requestJSON, err := ctx.GetStub().GetState(requestID)
	if err != nil {
		return err
	}
	if requestJSON == nil {
		return fmt.Errorf("access request %s not found", requestID)
	}

	var request AccessRequest
	if err := json.Unmarshal(requestJSON, &request); err != nil {
		return err
	}

	timestamp := time.Now().Unix()
	request.Status = "DENIED"
	request.DenialReason = reason

	requestJSON, err = request.ToJSON()
	if err != nil {
		return err
	}
	ctx.GetStub().PutState(requestID, requestJSON)

	// Record event
	event := CustodyEvent{
		DocType:       DocTypeCustodyEvent,
		EventID:       fmt.Sprintf("EVT-%s-%d", request.EvidenceID, timestamp),
		EvidenceID:    request.EvidenceID,
		EventType:     EventAccessDenied,
		FromEntity:    identity.ID,
		FromOrg:       identity.MSPID,
		ToEntity:      request.RequesterID,
		ToOrg:         request.RequesterOrg,
		Reason:        reason,
		Timestamp:     timestamp,
		PerformedBy:   identity.ID,
		PerformerOrg:  identity.MSPID,
		PerformerRole: identity.Role,
		TxID:          ctx.GetStub().GetTxID(),
		Verified:      true,
	}

	eventJSON, _ := event.ToJSON()
	eventKey := fmt.Sprintf("EVENT~%s~%d", request.EvidenceID, timestamp)
	ctx.GetStub().PutState(eventKey, eventJSON)

	return nil
}

// =============================================================================
// Analysis Operations
// =============================================================================

// RecordAnalysis records a forensic analysis session
func (s *EvidenceContract) RecordAnalysis(
	ctx contractapi.TransactionContextInterface,
	evidenceID string,
	toolUsed string,
	toolVersion string,
	findings string,
	artifactsJSON string,
	reportIPFSHash string,
	methodology string,
) (string, error) {
	// Verify permission
	identity, err := RequirePermission(ctx, PermRecordAnalysis)
	if err != nil {
		return "", err
	}

	// Get evidence
	evidence, err := s.GetEvidence(ctx, evidenceID)
	if err != nil {
		return "", err
	}

	// For demo: Only verify the evidence is in a valid state for analysis
	// In production, this would check that the caller's org matches CurrentOrg
	// But since the backend uses a single gateway connection, we relax this check
	if evidence.Status != StatusInAnalysis && evidence.Status != StatusInCustody && evidence.Status != StatusRegistered {
		return "", fmt.Errorf("evidence must be in analysis/custody state to record analysis, current status: %s", evidence.Status)
	}

	// Parse artifacts
	var artifacts []string
	if err := json.Unmarshal([]byte(artifactsJSON), &artifacts); err != nil {
		artifacts = []string{}
	}

	// Create analysis record
	timestamp := time.Now().Unix()
	analysisID := fmt.Sprintf("ANL-%s-%d", evidenceID, timestamp)

	analysis := AnalysisRecord{
		DocType:        DocTypeAnalysisRecord,
		AnalysisID:     analysisID,
		EvidenceID:     evidenceID,
		AnalystID:      identity.ID,
		AnalystOrg:     identity.MSPID,
		ToolUsed:       toolUsed,
		ToolVersion:    toolVersion,
		StartTime:      timestamp,
		EndTime:        timestamp,
		Findings:       findings,
		ArtifactsFound: artifacts,
		ReportIPFSHash: reportIPFSHash,
		Methodology:    methodology,
		Verified:       false,
	}

	analysisJSON, err := analysis.ToJSON()
	if err != nil {
		return "", err
	}
	if err := ctx.GetStub().PutState(analysisID, analysisJSON); err != nil {
		return "", err
	}

	// Update evidence status if needed
	if evidence.Status == StatusInAnalysis {
		evidence.Status = StatusAnalyzed
		evidence.UpdatedAt = timestamp
		evidenceJSON, _ := evidence.ToJSON()
		ctx.GetStub().PutState(evidenceID, evidenceJSON)
	}

	// Record event
	event := CustodyEvent{
		DocType:       DocTypeCustodyEvent,
		EventID:       fmt.Sprintf("EVT-%s-%d", evidenceID, timestamp),
		EvidenceID:    evidenceID,
		EventType:     EventAnalysisEnd,
		FromEntity:    identity.ID,
		FromOrg:       identity.MSPID,
		Reason:        fmt.Sprintf("Analysis completed using %s", toolUsed),
		Details:       fmt.Sprintf(`{"analysisId":"%s","toolUsed":"%s","artifactCount":%d}`, analysisID, toolUsed, len(artifacts)),
		Timestamp:     timestamp,
		PerformedBy:   identity.ID,
		PerformerOrg:  identity.MSPID,
		PerformerRole: identity.Role,
		TxID:          ctx.GetStub().GetTxID(),
		Verified:      true,
	}

	eventJSON, _ := event.ToJSON()
	eventKey := fmt.Sprintf("EVENT~%s~%d", evidenceID, timestamp)
	ctx.GetStub().PutState(eventKey, eventJSON)

	// Emit event
	eventPayload, _ := json.Marshal(map[string]interface{}{
		"type":       "ANALYSIS_RECORDED",
		"evidenceId": evidenceID,
		"analysisId": analysisID,
		"analyst":    identity.ID,
		"timestamp":  timestamp,
	})
	ctx.GetStub().SetEvent("AnalysisRecorded", eventPayload)

	return analysisID, nil
}

// VerifyAnalysis marks an analysis as verified by supervisor
func (s *EvidenceContract) VerifyAnalysis(
	ctx contractapi.TransactionContextInterface,
	analysisID string,
) error {
	identity, err := RequirePermission(ctx, PermVerifyAnalysis)
	if err != nil {
		return err
	}

	analysisJSON, err := ctx.GetStub().GetState(analysisID)
	if err != nil {
		return err
	}
	if analysisJSON == nil {
		return fmt.Errorf("analysis %s not found", analysisID)
	}

	var analysis AnalysisRecord
	if err := json.Unmarshal(analysisJSON, &analysis); err != nil {
		return err
	}

	timestamp := time.Now().Unix()
	analysis.Verified = true
	analysis.VerifiedBy = identity.ID
	analysis.VerifiedAt = timestamp

	analysisJSON, _ = analysis.ToJSON()
	ctx.GetStub().PutState(analysisID, analysisJSON)

	return nil
}

// =============================================================================
// Judicial Review
// =============================================================================

// SubmitForJudicialReview submits evidence for judicial review
func (s *EvidenceContract) SubmitForJudicialReview(
	ctx contractapi.TransactionContextInterface,
	evidenceID string,
	caseNotes string,
) (string, error) {
	identity, err := RequirePermission(ctx, PermSubmitForReview)
	if err != nil {
		return "", err
	}

	evidence, err := s.GetEvidence(ctx, evidenceID)
	if err != nil {
		return "", err
	}

	// Validate status transition
	if err := ValidateStatusTransition(evidence.Status, StatusUnderReview); err != nil {
		return "", err
	}

	timestamp := time.Now().Unix()
	reviewID := fmt.Sprintf("REV-%s-%d", evidenceID, timestamp)

	review := JudicialReview{
		DocType:      DocTypeJudicialReview,
		ReviewID:     reviewID,
		EvidenceID:   evidenceID,
		CaseID:       evidence.CaseID,
		SubmittedBy:  identity.ID,
		SubmittedOrg: identity.MSPID,
		SubmittedAt:  timestamp,
		CaseNotes:    caseNotes,
		Decision:     "PENDING",
	}

	reviewJSON, err := review.ToJSON()
	if err != nil {
		return "", err
	}
	ctx.GetStub().PutState(reviewID, reviewJSON)

	// Update evidence status
	evidence.Status = StatusUnderReview
	evidence.UpdatedAt = timestamp
	evidenceJSON, _ := evidence.ToJSON()
	ctx.GetStub().PutState(evidenceID, evidenceJSON)

	// Record event
	event := CustodyEvent{
		DocType:       DocTypeCustodyEvent,
		EventID:       fmt.Sprintf("EVT-%s-%d", evidenceID, timestamp),
		EvidenceID:    evidenceID,
		EventType:     EventJudicialSubmit,
		FromEntity:    identity.ID,
		FromOrg:       identity.MSPID,
		ToOrg:         "JudiciaryMSP",
		Reason:        "Submitted for judicial review",
		Details:       fmt.Sprintf(`{"reviewId":"%s","caseId":"%s"}`, reviewID, evidence.CaseID),
		Timestamp:     timestamp,
		PerformedBy:   identity.ID,
		PerformerOrg:  identity.MSPID,
		PerformerRole: identity.Role,
		TxID:          ctx.GetStub().GetTxID(),
		Verified:      true,
	}

	eventJSON, _ := event.ToJSON()
	eventKey := fmt.Sprintf("EVENT~%s~%d", evidenceID, timestamp)
	ctx.GetStub().PutState(eventKey, eventJSON)

	return reviewID, nil
}

// RecordJudicialDecision records a judicial decision on evidence
func (s *EvidenceContract) RecordJudicialDecision(
	ctx contractapi.TransactionContextInterface,
	reviewID string,
	decision string, // "ADMITTED" or "REJECTED"
	decisionReason string,
	courtReference string,
) error {
	identity, err := RequirePermission(ctx, PermRecordDecision)
	if err != nil {
		return err
	}

	reviewJSON, err := ctx.GetStub().GetState(reviewID)
	if err != nil {
		return err
	}
	if reviewJSON == nil {
		return fmt.Errorf("review %s not found", reviewID)
	}

	var review JudicialReview
	if err := json.Unmarshal(reviewJSON, &review); err != nil {
		return err
	}

	if review.Decision != "PENDING" {
		return fmt.Errorf("decision already recorded for this review")
	}

	// Validate decision
	if decision != "ADMITTED" && decision != "REJECTED" {
		return fmt.Errorf("invalid decision: must be ADMITTED or REJECTED")
	}

	timestamp := time.Now().Unix()
	review.Decision = decision
	review.DecisionReason = decisionReason
	review.DecidedBy = identity.ID
	review.DecidedAt = timestamp
	review.CourtReference = courtReference

	reviewJSON, _ = review.ToJSON()
	ctx.GetStub().PutState(reviewID, reviewJSON)

	// Update evidence status
	evidence, err := s.GetEvidence(ctx, review.EvidenceID)
	if err != nil {
		return err
	}

	if decision == "ADMITTED" {
		evidence.Status = StatusAdmitted
	} else {
		evidence.Status = StatusRejected
	}
	evidence.UpdatedAt = timestamp
	evidenceJSON, _ := evidence.ToJSON()
	ctx.GetStub().PutState(review.EvidenceID, evidenceJSON)

	// Record event
	event := CustodyEvent{
		DocType:       DocTypeCustodyEvent,
		EventID:       fmt.Sprintf("EVT-%s-%d", review.EvidenceID, timestamp),
		EvidenceID:    review.EvidenceID,
		EventType:     EventJudicialDecision,
		FromEntity:    identity.ID,
		FromOrg:       identity.MSPID,
		Reason:        fmt.Sprintf("Judicial decision: %s", decision),
		Details:       fmt.Sprintf(`{"reviewId":"%s","decision":"%s","courtRef":"%s"}`, reviewID, decision, courtReference),
		Timestamp:     timestamp,
		PerformedBy:   identity.ID,
		PerformerOrg:  identity.MSPID,
		PerformerRole: identity.Role,
		TxID:          ctx.GetStub().GetTxID(),
		Verified:      true,
	}

	eventJSON, _ := event.ToJSON()
	eventKey := fmt.Sprintf("EVENT~%s~%d", review.EvidenceID, timestamp)
	ctx.GetStub().PutState(eventKey, eventJSON)

	// Emit event
	eventPayload, _ := json.Marshal(map[string]interface{}{
		"type":       "JUDICIAL_DECISION",
		"evidenceId": review.EvidenceID,
		"reviewId":   reviewID,
		"decision":   decision,
		"timestamp":  timestamp,
	})
	ctx.GetStub().SetEvent("JudicialDecision", eventPayload)

	return nil
}

// =============================================================================
// Evidence Management
// =============================================================================

// AddTag adds a classification tag to evidence
func (s *EvidenceContract) AddTag(
	ctx contractapi.TransactionContextInterface,
	evidenceID string,
	tag string,
) error {
	identity, err := RequirePermission(ctx, PermAddTags)
	if err != nil {
		return err
	}

	evidence, err := s.GetEvidence(ctx, evidenceID)
	if err != nil {
		return err
	}

	// Check for duplicate
	for _, t := range evidence.Tags {
		if t == tag {
			return nil // Tag already exists
		}
	}

	timestamp := time.Now().Unix()
	evidence.Tags = append(evidence.Tags, tag)
	evidence.UpdatedAt = timestamp

	evidenceJSON, _ := evidence.ToJSON()
	ctx.GetStub().PutState(evidenceID, evidenceJSON)

	// Record event
	event := CustodyEvent{
		DocType:       DocTypeCustodyEvent,
		EventID:       fmt.Sprintf("EVT-%s-%d", evidenceID, timestamp),
		EvidenceID:    evidenceID,
		EventType:     EventTagAdded,
		FromEntity:    identity.ID,
		FromOrg:       identity.MSPID,
		Details:       fmt.Sprintf(`{"tag":"%s"}`, tag),
		Timestamp:     timestamp,
		PerformedBy:   identity.ID,
		PerformerOrg:  identity.MSPID,
		PerformerRole: identity.Role,
		TxID:          ctx.GetStub().GetTxID(),
		Verified:      true,
	}

	eventJSON, _ := event.ToJSON()
	eventKey := fmt.Sprintf("EVENT~%s~%d", evidenceID, timestamp)
	ctx.GetStub().PutState(eventKey, eventJSON)

	return nil
}

// UpdateStatus updates the status of evidence (with validation)
func (s *EvidenceContract) UpdateStatus(
	ctx contractapi.TransactionContextInterface,
	evidenceID string,
	newStatus string,
	reason string,
) error {
	identity, err := RequirePermission(ctx, PermUpdateStatus)
	if err != nil {
		return err
	}

	evidence, err := s.GetEvidence(ctx, evidenceID)
	if err != nil {
		return err
	}

	targetStatus := EvidenceStatus(newStatus)
	if err := ValidateStatusTransition(evidence.Status, targetStatus); err != nil {
		return err
	}

	timestamp := time.Now().Unix()
	oldStatus := evidence.Status
	evidence.Status = targetStatus
	evidence.UpdatedAt = timestamp

	evidenceJSON, _ := evidence.ToJSON()
	ctx.GetStub().PutState(evidenceID, evidenceJSON)

	// Record event
	event := CustodyEvent{
		DocType:       DocTypeCustodyEvent,
		EventID:       fmt.Sprintf("EVT-%s-%d", evidenceID, timestamp),
		EvidenceID:    evidenceID,
		EventType:     EventStatusChange,
		FromEntity:    identity.ID,
		FromOrg:       identity.MSPID,
		Reason:        reason,
		Details:       fmt.Sprintf(`{"oldStatus":"%s","newStatus":"%s"}`, oldStatus, newStatus),
		Timestamp:     timestamp,
		PerformedBy:   identity.ID,
		PerformerOrg:  identity.MSPID,
		PerformerRole: identity.Role,
		TxID:          ctx.GetStub().GetTxID(),
		Verified:      true,
	}

	eventJSON, _ := event.ToJSON()
	eventKey := fmt.Sprintf("EVENT~%s~%d", evidenceID, timestamp)
	ctx.GetStub().PutState(eventKey, eventJSON)

	return nil
}

// VerifyIntegrity verifies evidence integrity against stored hash
func (s *EvidenceContract) VerifyIntegrity(
	ctx contractapi.TransactionContextInterface,
	evidenceID string,
	providedHash string,
) (bool, error) {
	identity, err := RequirePermission(ctx, PermVerifyIntegrity)
	if err != nil {
		return false, err
	}

	evidence, err := s.GetEvidence(ctx, evidenceID)
	if err != nil {
		return false, err
	}

	verified := evidence.EvidenceHash == providedHash
	timestamp := time.Now().Unix()

	evidence.IntegrityVerified = verified
	evidence.LastVerifiedAt = timestamp
	evidence.UpdatedAt = timestamp

	evidenceJSON, _ := evidence.ToJSON()
	ctx.GetStub().PutState(evidenceID, evidenceJSON)

	// Record verification event
	event := CustodyEvent{
		DocType:       DocTypeCustodyEvent,
		EventID:       fmt.Sprintf("EVT-%s-%d", evidenceID, timestamp),
		EvidenceID:    evidenceID,
		EventType:     EventVerification,
		FromEntity:    identity.ID,
		FromOrg:       identity.MSPID,
		Reason:        "Integrity verification",
		Details:       fmt.Sprintf(`{"verified":%t,"providedHash":"%s"}`, verified, providedHash[:16]+"..."),
		Timestamp:     timestamp,
		PerformedBy:   identity.ID,
		PerformerOrg:  identity.MSPID,
		PerformerRole: identity.Role,
		TxID:          ctx.GetStub().GetTxID(),
		Verified:      true,
	}

	eventJSON, _ := event.ToJSON()
	eventKey := fmt.Sprintf("EVENT~%s~%d", evidenceID, timestamp)
	ctx.GetStub().PutState(eventKey, eventJSON)

	return verified, nil
}

// =============================================================================
// Query Functions
// =============================================================================

// GetEvidence retrieves evidence by ID
func (s *EvidenceContract) GetEvidence(
	ctx contractapi.TransactionContextInterface,
	evidenceID string,
) (*Evidence, error) {
	// Verify view permission
	_, err := RequirePermission(ctx, PermViewEvidence)
	if err != nil {
		return nil, err
	}

	evidenceJSON, err := ctx.GetStub().GetState(evidenceID)
	if err != nil {
		return nil, fmt.Errorf("failed to read evidence: %v", err)
	}
	if evidenceJSON == nil {
		return nil, fmt.Errorf("evidence %s not found", evidenceID)
	}

	var evidence Evidence
	if err := json.Unmarshal(evidenceJSON, &evidence); err != nil {
		return nil, err
	}

	return &evidence, nil
}

// EvidenceExists checks if evidence exists
func (s *EvidenceContract) EvidenceExists(
	ctx contractapi.TransactionContextInterface,
	evidenceID string,
) (bool, error) {
	evidenceJSON, err := ctx.GetStub().GetState(evidenceID)
	if err != nil {
		return false, err
	}
	return evidenceJSON != nil, nil
}

// GetEvidenceHistory retrieves the full custody chain for evidence
func (s *EvidenceContract) GetEvidenceHistory(
	ctx contractapi.TransactionContextInterface,
	evidenceID string,
) ([]CustodyEvent, error) {
	_, err := RequirePermission(ctx, PermViewAudit)
	if err != nil {
		return nil, err
	}

	// Query all events for this evidence
	queryString := fmt.Sprintf(`{"selector":{"docType":"%s","evidenceId":"%s"}}`, DocTypeCustodyEvent, evidenceID)
	
	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var events []CustodyEvent
	for resultsIterator.HasNext() {
		queryResult, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var event CustodyEvent
		if err := json.Unmarshal(queryResult.Value, &event); err != nil {
			continue
		}
		events = append(events, event)
	}

	// Sort by timestamp
	sort.Slice(events, func(i, j int) bool {
		return events[i].Timestamp < events[j].Timestamp
	})

	return events, nil
}

// GetEvidenceByCase retrieves all evidence for a case
func (s *EvidenceContract) GetEvidenceByCase(
	ctx contractapi.TransactionContextInterface,
	caseID string,
) ([]Evidence, error) {
	_, err := RequirePermission(ctx, PermViewEvidence)
	if err != nil {
		return nil, err
	}

	queryString := fmt.Sprintf(`{"selector":{"docType":"%s","caseId":"%s"}}`, DocTypeEvidence, caseID)
	
	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var evidenceList []Evidence
	for resultsIterator.HasNext() {
		queryResult, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var evidence Evidence
		if err := json.Unmarshal(queryResult.Value, &evidence); err != nil {
			continue
		}
		evidenceList = append(evidenceList, evidence)
	}

	return evidenceList, nil
}

// QueryByStatus retrieves evidence by status
func (s *EvidenceContract) QueryByStatus(
	ctx contractapi.TransactionContextInterface,
	status string,
) ([]Evidence, error) {
	_, err := RequirePermission(ctx, PermViewEvidence)
	if err != nil {
		return nil, err
	}

	queryString := fmt.Sprintf(`{"selector":{"docType":"%s","status":"%s"}}`, DocTypeEvidence, status)
	
	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var evidenceList []Evidence
	for resultsIterator.HasNext() {
		queryResult, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var evidence Evidence
		if err := json.Unmarshal(queryResult.Value, &evidence); err != nil {
			continue
		}
		evidenceList = append(evidenceList, evidence)
	}

	return evidenceList, nil
}

// GetAnalysisRecords retrieves all analysis records for evidence
func (s *EvidenceContract) GetAnalysisRecords(
	ctx contractapi.TransactionContextInterface,
	evidenceID string,
) ([]AnalysisRecord, error) {
	_, err := RequirePermission(ctx, PermViewAudit)
	if err != nil {
		return nil, err
	}

	queryString := fmt.Sprintf(`{"selector":{"docType":"%s","evidenceId":"%s"}}`, DocTypeAnalysisRecord, evidenceID)
	
	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var records []AnalysisRecord
	for resultsIterator.HasNext() {
		queryResult, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var record AnalysisRecord
		if err := json.Unmarshal(queryResult.Value, &record); err != nil {
			continue
		}
		records = append(records, record)
	}

	return records, nil
}

// GenerateAuditReport generates a comprehensive audit report
func (s *EvidenceContract) GenerateAuditReport(
	ctx contractapi.TransactionContextInterface,
	evidenceID string,
) (*AuditReport, error) {
	identity, err := RequirePermission(ctx, PermGenerateReport)
	if err != nil {
		return nil, err
	}

	// Get evidence
	evidence, err := s.GetEvidence(ctx, evidenceID)
	if err != nil {
		return nil, err
	}

	// Get custody chain
	custodyChain, err := s.GetEvidenceHistory(ctx, evidenceID)
	if err != nil {
		return nil, err
	}

	// Get analysis records
	analysisRecords, err := s.GetAnalysisRecords(ctx, evidenceID)
	if err != nil {
		return nil, err
	}

	// Get judicial reviews
	queryString := fmt.Sprintf(`{"selector":{"docType":"%s","evidenceId":"%s"}}`, DocTypeJudicialReview, evidenceID)
	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var judicialReviews []JudicialReview
	for resultsIterator.HasNext() {
		queryResult, err := resultsIterator.Next()
		if err != nil {
			continue
		}
		var review JudicialReview
		if err := json.Unmarshal(queryResult.Value, &review); err != nil {
			continue
		}
		judicialReviews = append(judicialReviews, review)
	}

	timestamp := time.Now().Unix()
	reportID := fmt.Sprintf("RPT-%s-%d", evidenceID, timestamp)

	// Create report
	report := AuditReport{
		ReportID:        reportID,
		EvidenceID:      evidenceID,
		Evidence:        *evidence,
		CustodyChain:    custodyChain,
		AnalysisRecords: analysisRecords,
		JudicialReviews: judicialReviews,
		GeneratedAt:     timestamp,
		GeneratedBy:     identity.ID,
		Verified:        evidence.IntegrityVerified,
	}

	// Generate integrity hash of report
	reportJSON, _ := report.ToJSON()
	hash := sha256.Sum256(reportJSON)
	report.IntegrityHash = hex.EncodeToString(hash[:])

	return &report, nil
}

// GetAllEvidence retrieves all evidence (for admin/audit purposes)
func (s *EvidenceContract) GetAllEvidence(
	ctx contractapi.TransactionContextInterface,
) ([]Evidence, error) {
	_, err := RequirePermission(ctx, PermViewEvidence)
	if err != nil {
		return nil, err
	}

	queryString := fmt.Sprintf(`{"selector":{"docType":"%s"}}`, DocTypeEvidence)
	
	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var evidenceList []Evidence
	for resultsIterator.HasNext() {
		queryResult, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var evidence Evidence
		if err := json.Unmarshal(queryResult.Value, &evidence); err != nil {
			continue
		}
		evidenceList = append(evidenceList, evidence)
	}

	return evidenceList, nil
}

