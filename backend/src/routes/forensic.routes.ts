/**
 * Forensic Tool Integration Routes
 * 
 * Provides API endpoints for forensic tools to integrate with the system.
 * Design Decision: This implements the "Integration Gateway" pattern from the paper,
 * allowing external forensic tools (like Autopsy, EnCase) to automatically log
 * their actions to the blockchain.
 */

import { Router, Request, Response } from 'express';
import { authenticate } from '../middleware/auth';
import { requirePermission } from '../middleware/rbac';
import { logger } from '../config/logger';
import * as contracts from '../fabric/contracts';
import { ForensicToolAction } from '../types';

const router = Router();

// API key authentication for tool integrations
// In production, this would be a more robust API key system
const validApiKeys = new Map<string, { toolName: string; userId: string }>([
  ['autopsy-integration-key-001', { toolName: 'Autopsy', userId: 'analyst-fl-001' }],
  ['encase-integration-key-001', { toolName: 'EnCase', userId: 'analyst-fl-001' }],
  ['xways-integration-key-001', { toolName: 'X-Ways', userId: 'analyst-fl-001' }],
  ['ftk-integration-key-001', { toolName: 'FTK', userId: 'analyst-fl-001' }],
  ['demo-tool-key', { toolName: 'DemoForensicTool', userId: 'analyst-fl-001' }]
]);

/**
 * Middleware for API key authentication (for tool integrations)
 */
function authenticateApiKey(req: Request, res: Response, next: () => void) {
  const apiKey = req.headers['x-api-key'] as string;
  
  if (!apiKey) {
    res.status(401).json({
      success: false,
      error: 'API key required. Provide X-API-Key header.'
    });
    return;
  }
  
  const keyInfo = validApiKeys.get(apiKey);
  if (!keyInfo) {
    res.status(401).json({
      success: false,
      error: 'Invalid API key'
    });
    return;
  }
  
  // Attach tool info to request
  (req as any).toolInfo = keyInfo;
  next();
}

/**
 * POST /api/forensic/ingest
 * Endpoint for forensic tools to register evidence they've acquired
 * This allows tools like Autopsy to directly register evidence
 */
router.post('/ingest', authenticateApiKey, async (req: Request, res: Response) => {
  try {
    const toolInfo = (req as any).toolInfo;
    const { 
      evidenceId, 
      caseId, 
      ipfsHash, 
      evidenceHash,
      encryptionKeyId,
      metadata 
    } = req.body;
    
    if (!evidenceId || !caseId || !ipfsHash || !evidenceHash) {
      res.status(400).json({
        success: false,
        error: 'evidenceId, caseId, ipfsHash, and evidenceHash are required'
      });
      return;
    }
    
    // Enhance metadata with tool info
    const enhancedMetadata = {
      ...metadata,
      acquisitionTool: toolInfo.toolName,
      acquisitionNotes: `Ingested via ${toolInfo.toolName} integration`
    };
    
    await contracts.registerEvidence(
      evidenceId,
      caseId,
      ipfsHash,
      evidenceHash,
      encryptionKeyId || '',
      enhancedMetadata
    );
    
    logger.info(`Evidence ingested via ${toolInfo.toolName}: ${evidenceId}`);
    
    res.status(201).json({
      success: true,
      data: { evidenceId },
      message: `Evidence ingested via ${toolInfo.toolName}`
    });
    
  } catch (error) {
    logger.error('Error ingesting evidence:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to ingest evidence'
    });
  }
});

/**
 * POST /api/forensic/action
 * Logs a forensic tool action to the blockchain
 * This is the main integration point for forensic tools to record their activities
 */
router.post('/action', authenticateApiKey, async (req: Request, res: Response) => {
  try {
    const toolInfo = (req as any).toolInfo;
    const action: ForensicToolAction = req.body;
    
    if (!action.evidenceId || !action.actionType) {
      res.status(400).json({
        success: false,
        error: 'evidenceId and actionType are required'
      });
      return;
    }
    
    // Map action types to appropriate chaincode calls
    switch (action.actionType) {
      case 'ANALYSIS_START':
      case 'ANALYSIS_COMPLETE':
        // Record as analysis
        const analysisId = await contracts.recordAnalysis(
          action.evidenceId,
          toolInfo.toolName,
          action.toolVersion || '1.0',
          JSON.stringify(action.details),
          action.details?.artifacts as string[] || [],
          '', // reportIPFSHash
          action.details?.methodology as string || ''
        );
        
        res.json({
          success: true,
          data: { analysisId },
          message: `Analysis action recorded: ${action.actionType}`
        });
        break;
        
      case 'FILE_ACCESSED':
      case 'ARTIFACT_EXTRACTED':
      case 'HASH_VERIFIED':
      case 'EXPORT_PERFORMED':
        // Record as a tag with details
        const tagValue = `${action.actionType}:${toolInfo.toolName}:${Date.now()}`;
        await contracts.addTag(action.evidenceId, tagValue);
        
        res.json({
          success: true,
          message: `Action logged: ${action.actionType}`
        });
        break;
        
      case 'INTEGRITY_CHECK':
        // Verify integrity if hash provided
        if (action.details?.hash) {
          const verified = await contracts.verifyIntegrity(
            action.evidenceId,
            action.details.hash as string
          );
          
          res.json({
            success: true,
            data: { verified },
            message: `Integrity check: ${verified ? 'PASSED' : 'FAILED'}`
          });
        } else {
          res.status(400).json({
            success: false,
            error: 'hash required in details for INTEGRITY_CHECK'
          });
        }
        break;
        
      default:
        // Log as generic tag
        await contracts.addTag(
          action.evidenceId, 
          `TOOL_ACTION:${toolInfo.toolName}:${action.actionType}`
        );
        
        res.json({
          success: true,
          message: `Generic action logged: ${action.actionType}`
        });
    }
    
    logger.info(`Forensic action recorded: ${action.actionType} for ${action.evidenceId} via ${toolInfo.toolName}`);
    
  } catch (error) {
    logger.error('Error recording forensic action:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to record forensic action'
    });
  }
});

/**
 * GET /api/forensic/evidence/:id
 * Gets evidence details for forensic tools
 */
router.get('/evidence/:id', authenticateApiKey, async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const evidence = await contracts.getEvidence(id);
    
    res.json({
      success: true,
      data: evidence
    });
    
  } catch (error) {
    logger.error(`Error retrieving evidence for forensic tool:`, error);
    res.status(404).json({
      success: false,
      error: 'Evidence not found'
    });
  }
});

/**
 * POST /api/forensic/batch-actions
 * Records multiple forensic actions in batch
 */
router.post('/batch-actions', authenticateApiKey, async (req: Request, res: Response) => {
  try {
    const toolInfo = (req as any).toolInfo;
    const { actions } = req.body;
    
    if (!Array.isArray(actions) || actions.length === 0) {
      res.status(400).json({
        success: false,
        error: 'actions array is required'
      });
      return;
    }
    
    const results = [];
    const errors = [];
    
    for (const action of actions) {
      try {
        const tagValue = `${action.actionType}:${toolInfo.toolName}:${action.timestamp || Date.now()}`;
        await contracts.addTag(action.evidenceId, tagValue);
        results.push({ evidenceId: action.evidenceId, actionType: action.actionType, status: 'success' });
      } catch (e) {
        errors.push({ evidenceId: action.evidenceId, actionType: action.actionType, error: (e as Error).message });
      }
    }
    
    logger.info(`Batch actions recorded: ${results.length} success, ${errors.length} errors`);
    
    res.json({
      success: errors.length === 0,
      data: {
        successful: results,
        failed: errors
      },
      message: `Processed ${results.length} actions, ${errors.length} errors`
    });
    
  } catch (error) {
    logger.error('Error recording batch actions:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to record batch actions'
    });
  }
});

/**
 * GET /api/forensic/api-info
 * Returns API documentation for forensic tool integration
 */
router.get('/api-info', (req: Request, res: Response) => {
  res.json({
    success: true,
    data: {
      name: 'Evidentia Forensic Tool Integration API',
      version: '1.0',
      authentication: {
        type: 'API Key',
        header: 'X-API-Key',
        description: 'Contact administrator for API key'
      },
      endpoints: [
        {
          method: 'POST',
          path: '/api/forensic/ingest',
          description: 'Register evidence acquired by forensic tool',
          body: {
            evidenceId: 'string (required)',
            caseId: 'string (required)',
            ipfsHash: 'string (required)',
            evidenceHash: 'string (required)',
            encryptionKeyId: 'string (optional)',
            metadata: 'object (optional)'
          }
        },
        {
          method: 'POST',
          path: '/api/forensic/action',
          description: 'Log forensic tool action',
          body: {
            evidenceId: 'string (required)',
            actionType: 'string (required) - ANALYSIS_START, ANALYSIS_COMPLETE, FILE_ACCESSED, ARTIFACT_EXTRACTED, HASH_VERIFIED, EXPORT_PERFORMED, INTEGRITY_CHECK',
            toolVersion: 'string (optional)',
            details: 'object (optional)'
          }
        },
        {
          method: 'GET',
          path: '/api/forensic/evidence/:id',
          description: 'Get evidence details'
        },
        {
          method: 'POST',
          path: '/api/forensic/batch-actions',
          description: 'Log multiple actions in batch',
          body: {
            actions: 'array of action objects'
          }
        }
      ],
      supportedTools: [
        'Autopsy',
        'EnCase',
        'X-Ways',
        'FTK',
        'Custom tools (contact admin for integration)'
      ]
    }
  });
});

export default router;

