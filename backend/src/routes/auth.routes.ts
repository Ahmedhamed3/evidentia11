/**
 * Authentication Routes
 * 
 * Handles user authentication and token management.
 * Design Decision: For this demo, we use a simplified authentication
 * that maps predefined users to their Fabric identities.
 */

import { Router, Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { generateToken, authenticate } from '../middleware/auth';
import { User, Role } from '../types';
import { logger } from '../config/logger';

const router = Router();

// Demo users - In production, this would be a database
// Design Decision: Pre-configured users for each role/org combination
const demoUsers: Record<string, { password: string; user: User }> = {
  'collector@lawenforcement': {
    password: bcrypt.hashSync('password123', 10),
    user: {
      id: 'collector-le-001',
      username: 'collector@lawenforcement',
      organization: 'LawEnforcement',
      mspId: 'LawEnforcementMSP',
      role: Role.COLLECTOR,
      commonName: 'Officer Ahmed'
    }
  },
  'supervisor@lawenforcement': {
    password: bcrypt.hashSync('password123', 10),
    user: {
      id: 'supervisor-le-001',
      username: 'supervisor@lawenforcement',
      organization: 'LawEnforcement',
      mspId: 'LawEnforcementMSP',
      role: Role.SUPERVISOR,
      commonName: 'Sergeant Mohamed'
    }
  },
  'analyst@forensiclab': {
    password: bcrypt.hashSync('password123', 10),
    user: {
      id: 'analyst-fl-001',
      username: 'analyst@forensiclab',
      organization: 'ForensicLab',
      mspId: 'ForensicLabMSP',
      role: Role.ANALYST,
      commonName: 'Dr. Fatima'
    }
  },
  'supervisor@forensiclab': {
    password: bcrypt.hashSync('password123', 10),
    user: {
      id: 'supervisor-fl-001',
      username: 'supervisor@forensiclab',
      organization: 'ForensicLab',
      mspId: 'ForensicLabMSP',
      role: Role.SUPERVISOR,
      commonName: 'Dr. Khaled'
    }
  },
  'counsel@judiciary': {
    password: bcrypt.hashSync('password123', 10),
    user: {
      id: 'counsel-jd-001',
      username: 'counsel@judiciary',
      organization: 'Judiciary',
      mspId: 'JudiciaryMSP',
      role: Role.LEGAL_COUNSEL,
      commonName: 'Attorney Ali'
    }
  },
  'judge@judiciary': {
    password: bcrypt.hashSync('password123', 10),
    user: {
      id: 'judge-jd-001',
      username: 'judge@judiciary',
      organization: 'Judiciary',
      mspId: 'JudiciaryMSP',
      role: Role.JUDGE,
      commonName: 'Judge Sara'
    }
  },
  'auditor@judiciary': {
    password: bcrypt.hashSync('password123', 10),
    user: {
      id: 'auditor-jd-001',
      username: 'auditor@judiciary',
      organization: 'Judiciary',
      mspId: 'JudiciaryMSP',
      role: Role.AUDITOR,
      commonName: 'Auditor Omar'
    }
  },
  'admin': {
    password: bcrypt.hashSync('admin123', 10),
    user: {
      id: 'admin-001',
      username: 'admin',
      organization: 'LawEnforcement',
      mspId: 'LawEnforcementMSP',
      role: Role.ADMIN,
      commonName: 'System Administrator'
    }
  }
};

/**
 * POST /api/auth/login
 * Authenticates a user and returns a JWT token
 */
router.post('/login', async (req: Request, res: Response) => {
  try {
    const { username, password } = req.body;
    
    if (!username || !password) {
      res.status(400).json({
        success: false,
        error: 'Username and password are required'
      });
      return;
    }
    
    // Find user
    const userRecord = demoUsers[username];
    
    if (!userRecord) {
      logger.warn(`Login attempt for unknown user: ${username}`);
      res.status(401).json({
        success: false,
        error: 'Invalid credentials'
      });
      return;
    }
    
    // Verify password
    const validPassword = await bcrypt.compare(password, userRecord.password);
    
    if (!validPassword) {
      logger.warn(`Invalid password for user: ${username}`);
      res.status(401).json({
        success: false,
        error: 'Invalid credentials'
      });
      return;
    }
    
    // Generate token
    const token = generateToken(userRecord.user);
    
    logger.info(`User logged in: ${username}`);
    
    res.json({
      success: true,
      data: {
        token,
        user: userRecord.user,
        expiresIn: process.env.JWT_EXPIRATION || '24h'
      }
    });
    
  } catch (error) {
    logger.error('Login error:', error);
    res.status(500).json({
      success: false,
      error: 'Login failed'
    });
  }
});

/**
 * GET /api/auth/me
 * Returns the current authenticated user's information
 */
router.get('/me', authenticate, (req: Request, res: Response) => {
  res.json({
    success: true,
    data: {
      user: req.user
    }
  });
});

/**
 * POST /api/auth/refresh
 * Refreshes an existing token (returns new token)
 */
router.post('/refresh', authenticate, (req: Request, res: Response) => {
  if (!req.user) {
    res.status(401).json({
      success: false,
      error: 'Not authenticated'
    });
    return;
  }
  
  const token = generateToken(req.user);
  
  res.json({
    success: true,
    data: {
      token,
      expiresIn: process.env.JWT_EXPIRATION || '24h'
    }
  });
});

/**
 * GET /api/auth/users
 * Lists available demo users (for testing UI)
 */
router.get('/users', (req: Request, res: Response) => {
  const users = Object.entries(demoUsers).map(([username, record]) => ({
    username,
    organization: record.user.organization,
    role: record.user.role,
    commonName: record.user.commonName
  }));
  
  res.json({
    success: true,
    data: users,
    message: 'Demo users - password is "password123" for all except admin which is "admin123"'
  });
});

export default router;
