/**
 * Audit Routes
 * 
 * Handles audit report generation and compliance-related queries.
 * Provides the audit trail functionality described in the paper.
 */

import { Router, Request, Response } from 'express';
import { authenticate } from '../middleware/auth';
import { requirePermission } from '../middleware/rbac';
import { logger } from '../config/logger';
import * as contracts from '../fabric/contracts';

const router = Router();

// All routes require authentication
router.use(authenticate);

/**
 * GET /api/audit/report/:evidenceId
 * Generates a comprehensive audit report for evidence
 */
router.get('/report/:evidenceId', 
  requirePermission('audit:generate'),
  async (req: Request, res: Response) => {
    try {
      const { evidenceId } = req.params;
      
      const report = await contracts.generateAuditReport(evidenceId);
      
      logger.info(`Audit report generated for ${evidenceId} by ${req.user?.id}`);
      
      res.json({
        success: true,
        data: report
      });
      
    } catch (error) {
      logger.error(`Error generating audit report for ${req.params.evidenceId}:`, error);
      res.status(500).json({
        success: false,
        error: 'Failed to generate audit report'
      });
    }
  }
);

/**
 * GET /api/audit/custody-chain/:evidenceId
 * Gets the full custody chain for evidence
 */
router.get('/custody-chain/:evidenceId',
  requirePermission('audit:read'),
  async (req: Request, res: Response) => {
    try {
      const { evidenceId } = req.params;
      
      const history = await contracts.getEvidenceHistory(evidenceId);
      
      // Format as a custody chain with clear transitions
      const custodyChain = (history || []).map((event, index) => ({
        step: index + 1,
        timestamp: new Date(event.timestamp * 1000).toISOString(),
        eventType: event.eventType,
        from: event.fromEntity || 'N/A',
        fromOrg: event.fromOrg || 'N/A',
        to: event.toEntity || 'N/A',
        toOrg: event.toOrg || 'N/A',
        performedBy: event.performedBy,
        reason: event.reason,
        transactionId: event.txId,
        verified: event.verified
      }));
      
      res.json({
        success: true,
        data: {
          evidenceId,
          totalEvents: custodyChain.length,
          custodyChain
        }
      });
      
    } catch (error) {
      logger.error(`Error retrieving custody chain for ${req.params.evidenceId}:`, error);
      res.status(500).json({
        success: false,
        error: 'Failed to retrieve custody chain'
      });
    }
  }
);

/**
 * GET /api/audit/timeline/:evidenceId
 * Gets a timeline view of all events for evidence
 */
router.get('/timeline/:evidenceId',
  requirePermission('audit:read'),
  async (req: Request, res: Response) => {
    try {
      const { evidenceId } = req.params;
      
      // Get evidence details
      const evidence = await contracts.getEvidence(evidenceId);
      
      // Get custody events
      const events = await contracts.getEvidenceHistory(evidenceId);
      
      // Get analysis records
      const analyses = await contracts.getAnalysisRecords(evidenceId);
      
      // Combine and sort by timestamp
      const timeline = [
        // Evidence creation
        {
          type: 'EVIDENCE_CREATED',
          timestamp: evidence.createdAt,
          description: `Evidence registered by ${evidence.registeredBy}`,
          details: {
            caseId: evidence.caseId,
            status: 'REGISTERED'
          }
        },
        // Custody events
        ...(events || []).map(event => ({
          type: event.eventType,
          timestamp: event.timestamp,
          description: `${event.eventType} - ${event.reason || 'No reason provided'}`,
          details: {
            from: event.fromEntity,
            to: event.toEntity,
            performedBy: event.performedBy,
            txId: event.txId
          }
        })),
        // Analysis records
        ...(analyses || []).map(analysis => ({
          type: 'ANALYSIS',
          timestamp: analysis.startTime,
          description: `Analysis performed using ${analysis.toolUsed}`,
          details: {
            analysisId: analysis.analysisId,
            analyst: analysis.analystId,
            tool: analysis.toolUsed,
            verified: analysis.verified
          }
        }))
      ].sort((a, b) => a.timestamp - b.timestamp);
      
      // Add formatted timestamps
      const formattedTimeline = timeline.map((item, index) => ({
        ...item,
        step: index + 1,
        formattedTime: new Date(item.timestamp * 1000).toISOString()
      }));
      
      res.json({
        success: true,
        data: {
          evidenceId,
          currentStatus: evidence.status,
          currentCustodian: evidence.currentCustodian,
          totalEvents: formattedTimeline.length,
          timeline: formattedTimeline
        }
      });
      
    } catch (error) {
      logger.error(`Error retrieving timeline for ${req.params.evidenceId}:`, error);
      res.status(500).json({
        success: false,
        error: 'Failed to retrieve timeline'
      });
    }
  }
);

/**
 * GET /api/audit/case/:caseId
 * Gets audit summary for all evidence in a case
 */
router.get('/case/:caseId',
  requirePermission('audit:read'),
  async (req: Request, res: Response) => {
    try {
      const { caseId } = req.params;
      
      const evidence = await contracts.getEvidenceByCase(caseId);
      
      if (!evidence || evidence.length === 0) {
        res.json({
          success: true,
          data: {
            caseId,
            evidenceCount: 0,
            evidence: []
          }
        });
        return;
      }
      
      // Get summary for each piece of evidence
      const evidenceSummaries = await Promise.all(
        evidence.map(async (e) => {
          const history = await contracts.getEvidenceHistory(e.id);
          return {
            evidenceId: e.id,
            name: e.metadata.name,
            status: e.status,
            currentCustodian: e.currentCustodian,
            currentOrg: e.currentOrg,
            registeredAt: new Date(e.createdAt * 1000).toISOString(),
            eventCount: history?.length || 0,
            integrityVerified: e.integrityVerified
          };
        })
      );
      
      // Calculate case statistics
      const stats = {
        totalEvidence: evidence.length,
        byStatus: evidence.reduce((acc, e) => {
          acc[e.status] = (acc[e.status] || 0) + 1;
          return acc;
        }, {} as Record<string, number>),
        verifiedCount: evidence.filter(e => e.integrityVerified).length
      };
      
      res.json({
        success: true,
        data: {
          caseId,
          statistics: stats,
          evidence: evidenceSummaries
        }
      });
      
    } catch (error) {
      logger.error(`Error retrieving case audit for ${req.params.caseId}:`, error);
      res.status(500).json({
        success: false,
        error: 'Failed to retrieve case audit'
      });
    }
  }
);

/**
 * GET /api/audit/export/:evidenceId
 * Exports audit report in a court-ready format
 */
router.get('/export/:evidenceId',
  requirePermission('audit:generate'),
  async (req: Request, res: Response) => {
    try {
      const { evidenceId } = req.params;
      const { format } = req.query;
      
      const report = await contracts.generateAuditReport(evidenceId);
      
      if (format === 'json') {
        res.setHeader('Content-Type', 'application/json');
        res.setHeader('Content-Disposition', `attachment; filename="audit-${evidenceId}.json"`);
        res.json(report);
        return;
      }
      
      // Default: formatted text report
      const textReport = generateTextReport(report);
      
      res.setHeader('Content-Type', 'text/plain');
      res.setHeader('Content-Disposition', `attachment; filename="audit-${evidenceId}.txt"`);
      res.send(textReport);
      
    } catch (error) {
      logger.error(`Error exporting audit report for ${req.params.evidenceId}:`, error);
      res.status(500).json({
        success: false,
        error: 'Failed to export audit report'
      });
    }
  }
);

/**
 * Generates a text-formatted audit report
 */
function generateTextReport(report: any): string {
  const lines = [
    '================================================================================',
    '                    DIGITAL EVIDENCE CHAIN-OF-CUSTODY REPORT',
    '================================================================================',
    '',
    `Report ID: ${report.reportId}`,
    `Generated: ${new Date(report.generatedAt * 1000).toISOString()}`,
    `Generated By: ${report.generatedBy}`,
    `Integrity Hash: ${report.integrityHash}`,
    '',
    '--------------------------------------------------------------------------------',
    '                           EVIDENCE INFORMATION',
    '--------------------------------------------------------------------------------',
    '',
    `Evidence ID: ${report.evidence.id}`,
    `Case ID: ${report.evidence.caseId}`,
    `Name: ${report.evidence.metadata.name}`,
    `Type: ${report.evidence.metadata.type}`,
    `Size: ${report.evidence.metadata.size} bytes`,
    `SHA-256 Hash: ${report.evidence.evidenceHash}`,
    `IPFS CID: ${report.evidence.ipfsHash}`,
    `Current Status: ${report.evidence.status}`,
    `Current Custodian: ${report.evidence.currentCustodian}`,
    `Current Organization: ${report.evidence.currentOrg}`,
    `Integrity Verified: ${report.evidence.integrityVerified ? 'YES' : 'NO'}`,
    '',
    '--------------------------------------------------------------------------------',
    '                           CHAIN OF CUSTODY',
    '--------------------------------------------------------------------------------',
    ''
  ];
  
  if (report.custodyChain && report.custodyChain.length > 0) {
    report.custodyChain.forEach((event: any, index: number) => {
      lines.push(`[${index + 1}] ${event.eventType}`);
      lines.push(`    Time: ${new Date(event.timestamp * 1000).toISOString()}`);
      lines.push(`    From: ${event.fromEntity || 'N/A'} (${event.fromOrg || 'N/A'})`);
      lines.push(`    To: ${event.toEntity || 'N/A'} (${event.toOrg || 'N/A'})`);
      lines.push(`    Performed By: ${event.performedBy}`);
      lines.push(`    Reason: ${event.reason || 'N/A'}`);
      lines.push(`    Transaction: ${event.txId}`);
      lines.push('');
    });
  } else {
    lines.push('No custody events recorded.');
    lines.push('');
  }
  
  lines.push('--------------------------------------------------------------------------------');
  lines.push('                           ANALYSIS RECORDS');
  lines.push('--------------------------------------------------------------------------------');
  lines.push('');
  
  if (report.analysisRecords && report.analysisRecords.length > 0) {
    report.analysisRecords.forEach((analysis: any, index: number) => {
      lines.push(`[${index + 1}] Analysis ID: ${analysis.analysisId}`);
      lines.push(`    Analyst: ${analysis.analystId}`);
      lines.push(`    Tool: ${analysis.toolUsed} v${analysis.toolVersion}`);
      lines.push(`    Time: ${new Date(analysis.startTime * 1000).toISOString()}`);
      lines.push(`    Findings: ${analysis.findings}`);
      lines.push(`    Verified: ${analysis.verified ? 'YES' : 'NO'}`);
      lines.push('');
    });
  } else {
    lines.push('No analysis records.');
    lines.push('');
  }
  
  lines.push('--------------------------------------------------------------------------------');
  lines.push('                           JUDICIAL REVIEWS');
  lines.push('--------------------------------------------------------------------------------');
  lines.push('');
  
  if (report.judicialReviews && report.judicialReviews.length > 0) {
    report.judicialReviews.forEach((review: any, index: number) => {
      lines.push(`[${index + 1}] Review ID: ${review.reviewId}`);
      lines.push(`    Submitted By: ${review.submittedBy}`);
      lines.push(`    Submitted: ${new Date(review.submittedAt * 1000).toISOString()}`);
      lines.push(`    Decision: ${review.decision}`);
      lines.push(`    Decided By: ${review.decidedBy || 'Pending'}`);
      lines.push(`    Court Reference: ${review.courtReference || 'N/A'}`);
      lines.push('');
    });
  } else {
    lines.push('No judicial reviews.');
    lines.push('');
  }
  
  lines.push('================================================================================');
  lines.push('                           END OF REPORT');
  lines.push('================================================================================');
  
  return lines.join('\n');
}

/**
 * GET /api/audit/integrity-check/:evidenceId
 * Performs a full integrity verification
 */
router.get('/integrity-check/:evidenceId',
  requirePermission('audit:read'),
  async (req: Request, res: Response) => {
    try {
      const { evidenceId } = req.params;
      
      const evidence = await contracts.getEvidence(evidenceId);
      
      res.json({
        success: true,
        data: {
          evidenceId,
          evidenceHash: evidence.evidenceHash,
          integrityVerified: evidence.integrityVerified,
          lastVerifiedAt: evidence.lastVerifiedAt 
            ? new Date(evidence.lastVerifiedAt * 1000).toISOString()
            : null,
          ipfsHash: evidence.ipfsHash,
          recommendation: evidence.integrityVerified 
            ? 'Evidence integrity is verified' 
            : 'Evidence should be re-verified before use'
        }
      });
      
    } catch (error) {
      logger.error(`Error checking integrity for ${req.params.evidenceId}:`, error);
      res.status(500).json({
        success: false,
        error: 'Failed to check integrity'
      });
    }
  }
);

export default router;

