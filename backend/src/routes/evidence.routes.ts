/**
 * Evidence Routes
 * 
 * Handles all evidence-related API operations including registration,
 * custody transfer, analysis, and judicial review.
 */

import { Router, Request, Response } from 'express';
import multer from 'multer';
import { v4 as uuidv4 } from 'uuid';
import { authenticate } from '../middleware/auth';
import { requirePermission } from '../middleware/rbac';
import { logger } from '../config/logger';
import * as contracts from '../fabric/contracts';
import { uploadEvidence, downloadEvidence } from '../services/ipfs.service';
import { computeHash, generateKeyId } from '../services/encryption.service';
import { EvidenceMetadata } from '../types';

const router = Router();

// Configure multer for file uploads (memory storage)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 100 * 1024 * 1024 // 100MB limit
  }
});

// All routes require authentication
router.use(authenticate);

/**
 * GET /api/evidence
 * Lists all evidence (with optional filters)
 */
router.get('/', requirePermission('evidence:read'), async (req: Request, res: Response) => {
  try {
    const { caseId, status } = req.query;
    
    let evidence;
    
    if (caseId) {
      evidence = await contracts.getEvidenceByCase(caseId as string);
    } else if (status) {
      evidence = await contracts.queryByStatus(status as string);
    } else {
      evidence = await contracts.getAllEvidence();
    }
    
    res.json({
      success: true,
      data: evidence || [],
      count: evidence?.length || 0
    });
    
  } catch (error) {
    logger.error('Error listing evidence:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve evidence list'
    });
  }
});

/**
 * GET /api/evidence/:id
 * Gets a specific piece of evidence by ID
 */
router.get('/:id', requirePermission('evidence:read'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const evidence = await contracts.getEvidence(id);
    
    res.json({
      success: true,
      data: evidence
    });
    
  } catch (error) {
    logger.error(`Error retrieving evidence ${req.params.id}:`, error);
    res.status(404).json({
      success: false,
      error: 'Evidence not found'
    });
  }
});

/**
 * POST /api/evidence
 * Registers new evidence with file upload
 */
router.post('/', 
  requirePermission('evidence:create'),
  upload.single('file'),
  async (req: Request, res: Response) => {
    try {
      const { caseId, name, type, sourceDevice, location, notes } = req.body;
      const file = req.file;
      
      if (!caseId) {
        res.status(400).json({
          success: false,
          error: 'Case ID is required'
        });
        return;
      }
      
      if (!file) {
        res.status(400).json({
          success: false,
          error: 'Evidence file is required'
        });
        return;
      }
      
      // Generate evidence ID
      const evidenceId = `EVD-${uuidv4().substring(0, 8).toUpperCase()}`;
      
      // Compute hash of original file
      const evidenceHash = computeHash(file.buffer);
      
      // Generate encryption key ID
      const encryptionKeyId = generateKeyId();
      
      // Upload to IPFS with encryption
      const { cid: ipfsHash, encryptedSize } = await uploadEvidence(
        file.buffer,
        encryptionKeyId
      );
      
      // Prepare metadata
      const metadata: Partial<EvidenceMetadata> = {
        name: name || file.originalname,
        type: type || 'Unknown',
        size: file.size,
        mimeType: file.mimetype,
        sourceDevice: sourceDevice || '',
        acquisitionDate: Date.now(),
        acquisitionTool: 'Evidentia Gateway',
        acquisitionNotes: notes || '',
        location: location || '',
        examinerNotes: ''
      };
      
      // Register on blockchain using user's organization
      await contracts.registerEvidence(
        evidenceId,
        caseId,
        ipfsHash,
        evidenceHash,
        encryptionKeyId,
        metadata,
        req.user?.mspId
      );
      
      logger.info(`Evidence registered: ${evidenceId} by ${req.user?.id}`);
      
      res.status(201).json({
        success: true,
        data: {
          evidenceId,
          caseId,
          ipfsHash,
          evidenceHash,
          encryptedSize,
          metadata
        },
        message: 'Evidence registered successfully'
      });
      
    } catch (error) {
      logger.error('Error registering evidence:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to register evidence'
      });
    }
  }
);

/**
 * GET /api/evidence/:id/download
 * Downloads the evidence file
 */
router.get('/:id/download', requirePermission('evidence:read'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    
    // Get evidence details
    const evidence = await contracts.getEvidence(id);
    
    // Download from IPFS and decrypt
    const data = await downloadEvidence(
      evidence.ipfsHash,
      evidence.encryptionKeyId
    );
    
    // Set headers for file download
    res.setHeader('Content-Type', evidence.metadata.mimeType || 'application/octet-stream');
    res.setHeader('Content-Disposition', `attachment; filename="${evidence.metadata.name}"`);
    res.setHeader('Content-Length', data.length);
    
    res.send(data);
    
  } catch (error) {
    logger.error(`Error downloading evidence ${req.params.id}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to download evidence'
    });
  }
});

/**
 * POST /api/evidence/:id/transfer
 * Transfers custody of evidence
 */
router.post('/:id/transfer', requirePermission('evidence:transfer'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { toEntityId, toOrgMSP, reason } = req.body;
    
    if (!toEntityId || !toOrgMSP || !reason) {
      res.status(400).json({
        success: false,
        error: 'toEntityId, toOrgMSP, and reason are required'
      });
      return;
    }
    
    // Use the user's organization to sign the transaction
    await contracts.transferCustody(id, toEntityId, toOrgMSP, reason, req.user?.mspId);
    
    logger.info(`Custody transferred: ${id} to ${toEntityId} by ${req.user?.id}`);
    
    res.json({
      success: true,
      message: 'Custody transferred successfully'
    });
    
  } catch (error) {
    logger.error(`Error transferring custody for ${req.params.id}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to transfer custody'
    });
  }
});

/**
 * POST /api/evidence/:id/analysis
 * Records an analysis session
 */
router.post('/:id/analysis', requirePermission('evidence:analyze'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { toolUsed, toolVersion, findings, artifacts, methodology } = req.body;
    
    if (!toolUsed || !findings) {
      res.status(400).json({
        success: false,
        error: 'toolUsed and findings are required'
      });
      return;
    }
    
    // Use the user's organization (should be ForensicLabMSP) to sign the transaction
    const analysisId = await contracts.recordAnalysis(
      id,
      toolUsed,
      toolVersion || '1.0',
      findings,
      artifacts || [],
      '', // reportIPFSHash - could upload a report file
      methodology || '',
      req.user?.mspId
    );
    
    logger.info(`Analysis recorded: ${analysisId} for ${id} by ${req.user?.id}`);
    
    res.status(201).json({
      success: true,
      data: { analysisId },
      message: 'Analysis recorded successfully'
    });
    
  } catch (error) {
    logger.error(`Error recording analysis for ${req.params.id}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to record analysis'
    });
  }
});

/**
 * POST /api/evidence/:id/analysis/:analysisId/verify
 * Verifies an analysis
 */
router.post('/:id/analysis/:analysisId/verify', 
  requirePermission('evidence:analyze'),
  async (req: Request, res: Response) => {
    try {
      const { analysisId } = req.params;
      
      await contracts.verifyAnalysis(analysisId);
      
      res.json({
        success: true,
        message: 'Analysis verified successfully'
      });
      
    } catch (error) {
      logger.error(`Error verifying analysis ${req.params.analysisId}:`, error);
      res.status(500).json({
        success: false,
        error: 'Failed to verify analysis'
      });
    }
  }
);

/**
 * POST /api/evidence/:id/review
 * Submits evidence for judicial review
 */
router.post('/:id/review', requirePermission('evidence:review'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { caseNotes } = req.body;
    
    // Use the user's organization to sign the transaction
    const reviewId = await contracts.submitForJudicialReview(id, caseNotes || '', req.user?.mspId);
    
    logger.info(`Submitted for review: ${reviewId} for ${id} by ${req.user?.id}`);
    
    res.status(201).json({
      success: true,
      data: { reviewId },
      message: 'Evidence submitted for judicial review'
    });
    
  } catch (error) {
    logger.error(`Error submitting for review ${req.params.id}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to submit for judicial review'
    });
  }
});

/**
 * POST /api/evidence/:id/decision
 * Records a judicial decision
 */
router.post('/:id/decision', requirePermission('evidence:decide'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { reviewId, decision, decisionReason, courtReference } = req.body;
    
    if (!reviewId || !decision) {
      res.status(400).json({
        success: false,
        error: 'reviewId and decision are required'
      });
      return;
    }
    
    if (decision !== 'ADMITTED' && decision !== 'REJECTED') {
      res.status(400).json({
        success: false,
        error: 'decision must be ADMITTED or REJECTED'
      });
      return;
    }
    
    // Use the user's organization (should be JudiciaryMSP) to sign the transaction
    await contracts.recordJudicialDecision(
      reviewId,
      decision,
      decisionReason || '',
      courtReference || '',
      req.user?.mspId
    );
    
    logger.info(`Judicial decision recorded: ${decision} for ${id} by ${req.user?.id}`);
    
    res.json({
      success: true,
      message: `Evidence ${decision.toLowerCase()}`
    });
    
  } catch (error) {
    logger.error(`Error recording decision for ${req.params.id}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to record judicial decision'
    });
  }
});

/**
 * POST /api/evidence/:id/tag
 * Adds a tag to evidence
 */
router.post('/:id/tag', requirePermission('evidence:create'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { tag } = req.body;
    
    if (!tag) {
      res.status(400).json({
        success: false,
        error: 'tag is required'
      });
      return;
    }
    
    await contracts.addTag(id, tag);
    
    res.json({
      success: true,
      message: 'Tag added successfully'
    });
    
  } catch (error) {
    logger.error(`Error adding tag to ${req.params.id}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to add tag'
    });
  }
});

/**
 * POST /api/evidence/:id/verify
 * Verifies evidence integrity
 */
router.post('/:id/verify', requirePermission('evidence:read'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { hash } = req.body;
    
    if (!hash) {
      res.status(400).json({
        success: false,
        error: 'hash is required for verification'
      });
      return;
    }
    
    const verified = await contracts.verifyIntegrity(id, hash);
    
    res.json({
      success: true,
      data: { verified },
      message: verified ? 'Evidence integrity verified' : 'Evidence integrity check failed'
    });
    
  } catch (error) {
    logger.error(`Error verifying integrity for ${req.params.id}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to verify integrity'
    });
  }
});

/**
 * GET /api/evidence/:id/history
 * Gets the custody chain history
 */
router.get('/:id/history', requirePermission('evidence:read'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const history = await contracts.getEvidenceHistory(id);
    
    res.json({
      success: true,
      data: history || [],
      count: history?.length || 0
    });
    
  } catch (error) {
    logger.error(`Error retrieving history for ${req.params.id}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve evidence history'
    });
  }
});

/**
 * GET /api/evidence/:id/analysis
 * Gets all analysis records for evidence
 */
router.get('/:id/analysis', requirePermission('evidence:read'), async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const records = await contracts.getAnalysisRecords(id);
    
    res.json({
      success: true,
      data: records || [],
      count: records?.length || 0
    });
    
  } catch (error) {
    logger.error(`Error retrieving analysis records for ${req.params.id}:`, error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve analysis records'
    });
  }
});

export default router;

