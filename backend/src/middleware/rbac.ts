/**
 * Role-Based Access Control Middleware
 * 
 * Enforces role-based permissions at the API level.
 * This complements the chaincode-level RBAC for defense in depth.
 */

import { Request, Response, NextFunction } from 'express';
import { Role } from '../types';
import { logger } from '../config/logger';

// Permission types
export type Permission = 
  | 'evidence:read'
  | 'evidence:create'
  | 'evidence:transfer'
  | 'evidence:analyze'
  | 'evidence:review'
  | 'evidence:decide'
  | 'audit:read'
  | 'audit:generate'
  | 'admin:all';

// Role-Permission mapping
// Design Decision: Mirrors chaincode RBAC but at API level for defense in depth
const rolePermissions: Record<Role, Permission[]> = {
  [Role.COLLECTOR]: [
    'evidence:read',
    'evidence:create',
    'evidence:transfer',
    'audit:read'
  ],
  [Role.ANALYST]: [
    'evidence:read',
    'evidence:transfer',
    'evidence:analyze',
    'audit:read'
  ],
  [Role.SUPERVISOR]: [
    'evidence:read',
    'evidence:create',
    'evidence:transfer',
    'evidence:analyze',
    'evidence:review',
    'audit:read',
    'audit:generate'
  ],
  [Role.LEGAL_COUNSEL]: [
    'evidence:read',
    'evidence:review',
    'evidence:decide',
    'audit:read',
    'audit:generate'
  ],
  [Role.JUDGE]: [
    'evidence:read',
    'evidence:decide',
    'audit:read',
    'audit:generate'
  ],
  [Role.AUDITOR]: [
    'evidence:read',
    'audit:read',
    'audit:generate'
  ],
  [Role.ADMIN]: [
    'admin:all',
    'evidence:read',
    'evidence:create',
    'evidence:transfer',
    'evidence:analyze',
    'evidence:review',
    'evidence:decide',
    'audit:read',
    'audit:generate'
  ]
};

/**
 * Checks if a role has a specific permission
 */
export function hasPermission(role: Role, permission: Permission): boolean {
  const permissions = rolePermissions[role];
  if (!permissions) {
    return false;
  }
  
  // Admin has all permissions
  if (permissions.includes('admin:all')) {
    return true;
  }
  
  return permissions.includes(permission);
}

/**
 * Middleware factory for requiring specific permissions
 */
export function requirePermission(...requiredPermissions: Permission[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    // Check if user is authenticated
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
      return;
    }
    
    // Check if user has at least one of the required permissions
    const userRole = req.user.role;
    const hasAnyPermission = requiredPermissions.some(
      permission => hasPermission(userRole, permission)
    );
    
    if (!hasAnyPermission) {
      logger.warn(`Access denied for user ${req.user.id} with role ${userRole}. Required: ${requiredPermissions.join(' OR ')}`);
      
      res.status(403).json({
        success: false,
        error: 'Insufficient permissions',
        required: requiredPermissions,
        userRole: userRole
      });
      return;
    }
    
    next();
  };
}

/**
 * Middleware factory for requiring specific roles
 */
export function requireRole(...allowedRoles: Role[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
      return;
    }
    
    if (!allowedRoles.includes(req.user.role)) {
      logger.warn(`Access denied for user ${req.user.id}. Role ${req.user.role} not in ${allowedRoles.join(', ')}`);
      
      res.status(403).json({
        success: false,
        error: 'Role not authorized for this action',
        allowedRoles,
        userRole: req.user.role
      });
      return;
    }
    
    next();
  };
}

/**
 * Middleware for requiring same organization
 * Used for operations that should only be performed by same-org users
 */
export function requireSameOrg(orgGetter: (req: Request) => string | undefined) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
      return;
    }
    
    const targetOrg = orgGetter(req);
    
    if (targetOrg && req.user.mspId !== targetOrg) {
      // Allow admins to bypass org check
      if (req.user.role !== Role.ADMIN) {
        res.status(403).json({
          success: false,
          error: 'Operation restricted to same organization',
          userOrg: req.user.mspId,
          targetOrg
        });
        return;
      }
    }
    
    next();
  };
}

