/**
 * Authentication Middleware
 * 
 * Handles JWT-based authentication for API endpoints.
 * Design Decision: Using JWT tokens that encode the user's Fabric identity
 * and role information for stateless authentication.
 */

import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { User, Role } from '../types';
import { logger } from '../config/logger';

// Extend Express Request type to include user
declare global {
  namespace Express {
    interface Request {
      user?: User;
    }
  }
}

const JWT_SECRET = process.env.JWT_SECRET || 'development-secret-change-in-production';
const JWT_EXPIRATION = process.env.JWT_EXPIRATION || '24h';

/**
 * JWT token payload structure
 */
interface TokenPayload {
  id: string;
  username: string;
  organization: string;
  mspId: string;
  role: Role;
  commonName: string;
  iat: number;
  exp: number;
}

/**
 * Generates a JWT token for a user
 */
export function generateToken(user: User): string {
  const payload: Omit<TokenPayload, 'iat' | 'exp'> = {
    id: user.id,
    username: user.username,
    organization: user.organization,
    mspId: user.mspId,
    role: user.role,
    commonName: user.commonName
  };
  
  return jwt.sign(payload, JWT_SECRET, {
    expiresIn: JWT_EXPIRATION
  });
}

/**
 * Verifies and decodes a JWT token
 */
export function verifyToken(token: string): TokenPayload {
  return jwt.verify(token, JWT_SECRET) as TokenPayload;
}

/**
 * Authentication middleware
 * Verifies JWT token and attaches user to request
 */
export function authenticate(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  try {
    // Get token from header
    const authHeader = req.headers.authorization;
    
    if (!authHeader) {
      res.status(401).json({
        success: false,
        error: 'No authorization header provided'
      });
      return;
    }
    
    // Check Bearer token format
    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer') {
      res.status(401).json({
        success: false,
        error: 'Invalid authorization header format. Use: Bearer <token>'
      });
      return;
    }
    
    const token = parts[1];
    
    // Verify token
    const payload = verifyToken(token);
    
    // Attach user to request
    req.user = {
      id: payload.id,
      username: payload.username,
      organization: payload.organization,
      mspId: payload.mspId,
      role: payload.role,
      commonName: payload.commonName
    };
    
    next();
    
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      res.status(401).json({
        success: false,
        error: 'Token expired'
      });
      return;
    }
    
    if (error instanceof jwt.JsonWebTokenError) {
      res.status(401).json({
        success: false,
        error: 'Invalid token'
      });
      return;
    }
    
    logger.error('Authentication error:', error);
    res.status(500).json({
      success: false,
      error: 'Authentication error'
    });
  }
}

/**
 * Optional authentication middleware
 * Attaches user if token is present, but doesn't require it
 */
export function optionalAuth(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  try {
    const authHeader = req.headers.authorization;
    
    if (authHeader) {
      const parts = authHeader.split(' ');
      if (parts.length === 2 && parts[0] === 'Bearer') {
        const token = parts[1];
        const payload = verifyToken(token);
        
        req.user = {
          id: payload.id,
          username: payload.username,
          organization: payload.organization,
          mspId: payload.mspId,
          role: payload.role,
          commonName: payload.commonName
        };
      }
    }
    
    next();
    
  } catch {
    // Ignore errors - just continue without user
    next();
  }
}

